package FoodApp::Controller::Cart;
use strict;
use warnings;
use Data::Currency;

use Data::Dumper;

BEGIN {
    use base qw/Catalyst::Controller/;
    use Handel::Constants qw/:cart/;
    use FormValidator::Simple 0.17;
    use YAML 0.65;
};

=head1 NAME

FoodApp::Controller::Cart - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 COMPONENT

=cut

sub COMPONENT {
    my $self = shift->NEXT::COMPONENT(@_);

    $self->{'validator'} = FormValidator::Simple->new;
    $self->{'validator'}->set_messages(
        $_[0]->path_to('root', 'src', 'cart', 'messages.yml')
    );

    $self->{'profiles'} = YAML::LoadFile($_[0]->path_to('root', 'src', 'cart', 'profiles.yml'));

    return $self;
};

=head2 default 

Default action when browsing to /cart/. If no session exists, or the shopper
id isn't set, no cart will be loaded. This keeps non-shoppers like Google
and others from wasting sessions and cart records for no good reason.

=cut

sub default :Path {
    my ($self, $c) = @_;
    $c->stash->{'template'} = 'cart/default';


    if ($c->sessionid && $c->session->{'shopper'}) {
        if (my $cart = $c->forward('load')) {
            $c->stash->{'cart'} = $cart;
            $c->stash->{'items'} = $cart->items;
        };
    };
    
    if ( exists $c->stash->{'items'} && defined $c->stash->{'items'}) {
    	my $cart = $c->stash->{'cart'};
    	my @item_array = ();
    	
    	my @products = ();
    	my %recipes_hash = ();
    	
		my @isect = ();
		
		
		
		my %hash_confidenza = ();
    	
    	## Prendo singolarmente ciascun item presente nel carrello
    	foreach my $prod ($cart->items) {

			#$DB::single = 1;
    		## Per ciascun item risalgo al prodotto
    		my $res = $c->model('FoodAppDB::Product')->find( { name => $prod->sku } );
    		
    		push @item_array, $prod->sku;
    		
    		#push @products, $res->name;
    		
    		# Inserisco ciascun prodotto in un hash che ha come valore gli id
    		# delle ricette che contengono tale prodotto
			foreach my $temp_recipe ($res->uses) {
				$c->log->debug($temp_recipe->recipe_id);
				push @{ $recipes_hash {$res->name} }, $temp_recipe->recipe_id;	
			}
			
			## Codice per fare il profiling in base agli ordini presenti nel database.
			# Se un prodotto presente nel carrello ha un altro prodotto che spesso è 
			# associato a lui negli ordini, allora lo visualizzo all'utente.
			
			## Hash per salvare le associazioni fra ordini e prodotti associati
			my %order_hash = ();
			
			my $orders_item_rs = $c->model('FoodAppDB')->resultset('OrdersItem')->search( {item => $prod->sku} );
			while ( my $orders_item = $orders_item_rs->next ) {
				my $orders_rs = $c->model('FoodAppDB')->resultset('Order')->search( {id => $orders_item->order_id} );
				while (my $order = $orders_rs->next) {
					foreach my $o ($order->orders_items) {
						if ($o->item ne $prod->sku) {
							push @{	$order_hash {$order->id} }, $o->item;
						}
					}
				}
			}
			## Alla fine del ciclo l'hash contiene l'associazione fra gli ordini che contengono
			# il prodotto corrente presente nel carrello e gli altri prodotti che tale ordine contiene.

			#Stampa di prova
			$c->log->debug(Dumper (\\%order_hash));
		
			## Ora eseguo un conteggio degli altri prodotti presenti negli ordini
			# attraverso un hash
			my %count_prod = ();
		
			## Per ogni chiave nell'hash degli ordini contenenti il prodotto corrente
			## salvo l'array degli altri prodotti ordinati e lo inserisco come chiave
			## di un altro array che ha come valore il numero di occorrenze di tale
			## prodotto.
			my $pnum = 0; # Variabile per contare il num di ordini con il prodotto corrente
			foreach my $o (keys %order_hash) {
				my @ord = @{ $order_hash{$o}};
				$pnum++;
				foreach my $item (@ord) {
					$count_prod{$item}++;
				}
			}
			
			#Stampa di prova
			$c->log->debug(Dumper (\\%count_prod));
			
			my @prod_selected = ();
			
			## Ora applico una soglia per scegliere i prodotti da visualizzare all'utente
			foreach my $o (keys %count_prod) {
				## Scelgo come soglia il 50% degli ordini in cui tale prodotto compare.
				if ($count_prod{$o} > (0.5 * $pnum)) {
					push @prod_selected, $o; 
				}
			}
			if (@prod_selected) {
				push @{ $hash_confidenza{$prod->sku} }, @prod_selected; 
			}
			
			$c->log->debug('Prodotti da visualizzare');
			$c->log->debug(Dumper(@prod_selected));
			
												
    	} # Fine del ciclo sui prodotti presenti nel carrello
    	
    	$c->log->debug('Hash della confidenza');
    	$c->log->debug(Dumper(\\%hash_confidenza));
    	
    	## Salvo nello stash i prodotti trovati
    	my @list = ();
    	foreach my $k (keys %hash_confidenza) {
    		my @val = @{$hash_confidenza{$k}};
    		foreach my $v (@val) {
    			push @list, $c->model('FoodAppDB::Product')->find( { name => $v } );
			}
		}
		foreach my $l (@list) {
			$c->log->debug("***");
			$c->log->debug($l->name);
		}
		if (@list) {
			$c->stash( confidenza => [ @list ] );
		}
		
		
    	
    	## Stampa di prova
    	$c->log->debug(Dumper (\\%recipes_hash));    	
    	#$c->log->debug(Dumper(@products));
    	
    	## Definisco un hash per contare il numero di occorrenze degli id delle ricette
    	my %count = ();
    	## Conta il numero di prodotti presenti nel carrello
    	my $num;
    	
    	## Per ciascuna prodotto presente nell'hash, salvo l'array degli id delle
    	## ricette in cui tale prodotto è contenuto e per ciascun id lo inserisco
    	## nell'hash count assegnandoli come valore il numero di occorrenze di tale
    	## id all'interno del recipes_hash
    	foreach my $e (keys %recipes_hash) {
    		$num++;
    		my @r = @{ $recipes_hash{$e}};
    			foreach my $id (@r) { 
    				$count{$id}++;
    			}
    	}
    	
    	## Gli id delle ricette comuni a tutti i prodotti presenti nel carrello
    	## sono quelli con un numero di occorrenze esattamente pari al numero di
    	## prodotti presenti nel carrello.
    	## Inserisco i risultati nell'array @isect
    	foreach my $e (keys %count) {
    		if ($count{$e} == $num) {
    			push @isect, $e;
    		}
    	}
    	
    	##Stampe di prova
    	$c->log->debug(Dumper(\\%count));
    	$c->log->debug(Dumper(@isect));
    	$c->log->debug(Dumper($num));
    	
    	my @stash_recipes;
    	
    	foreach my $rec_id (@isect) {
    		push @stash_recipes, $c->model('FoodAppDB::Recipe')->find( 
    			{ id => $rec_id } );
    	}
    	
    	$c->stash(recipes => [ @stash_recipes ] );
    	$c->stash(item_array => [ @item_array] );
    }



    return;
};

=head2 add

=over

=item Parameters: (See L<Handel::Cart/add>)

=back

Adds an item to the current cart during POST.

    /cart/add/

=cut

sub add : Local {
    my ($self, $c) = @_;
    
    ## Variabile che serve per sapere se sono entrato all'interno del controllo if
    my $check_qty = 1;
    
    if ($c->req->method eq 'POST') {
    
    	my $params = $c->req->params;
    
    	## Controllo che la quantità richiesta sia disponibile
        my $product = $c->model('FoodAppDB::Product')->find( { name => $params->{sku} } );
        if ( ($product->stock_qty - $params->{quantity}) < 0 ) {
        	$c->log->debug("All'interno del controllo if...");
        	$check_qty = 0;
        	my $max_qty = $product->stock_qty;
        	$c->res->redirect($c->uri_for(
				$c->controller('Product')->action_for('list'),
				{status_msg => "La quantità massima disponibile di questo prodotto è $max_qty." }) );
        }
        else {
    	
        	my $cart = $c->forward('create');
        
        	#my $params = $c->req->params;
        	my $price = $params->{price};
        	if ($price =~ m/\,/) {
        		$price =~ s/\,/\./;
        	}
        
        	$params->{price} = $price;
        	$c->req->{params} = $params;
                
        	$cart->add($c->req->params);
        }
    };

	## Se sono entrato nell'if non faccio questo redirect che altrimenti sovrascriverebbe quello
	## precedente
	if ($check_qty) {
    	$c->res->redirect($c->uri_for('/cart/'));
    }
};

=head2 clear

Clears all items form the current shopping cart during POST.

    /cart/clear/

=cut

sub clear : Local {
    my ($self, $c) = @_;

    if ($c->req->method eq 'POST') {
        if (my $cart = $c->forward('load')) {
            $cart->clear;
        };
    };

    $c->res->redirect($c->uri_for('/cart/'));
};

=head2 create

Creats a new temporary shopping cart or returns the existing cart, creating a
new session shopper id if necessary.

    my $cart = $c->forward('create');

=cut

sub create : Private {
    my ($self, $c) = @_;

    if (!$c->session->{'shopper'}) {
        $c->session->{'shopper'} = $c->model('Cart')->storage->new_uuid;
    };

    if (my $cart = $c->forward('load')) {
        return $cart;
    } else {
        return $c->model('Cart')->create({
            shopper => $c->session->{'shopper'},
            type    => CART_TYPE_TEMP
        });
    };

    return;
};

=head2 delete

=over

=item Parameters: id

=back

Deletes an item from the current shopping cart during a POST.

    /cart/delete/

=cut

sub delete : Local {
    my ($self, $c) = @_;

    if ($c->req->method eq 'POST') {
        if ($c->forward('validate')) {
            if (my $cart = $c->forward('load')) {
                $cart->delete({
                    id => $c->req->params->{'id'}
                });

                $c->res->redirect($c->uri_for('/cart/'));
            };
        } else {
            $c->forward('default');
        };
    } else {
        $c->res->redirect($c->uri_for('/cart/'));
    };

    return;
};

=head2 destroy

=over

=item Parameters: id

=back

Deletes the specified saved cart and all of its items during a POST.

    /cart/destroy/

=cut

sub destroy : Local {
    my ($self, $c) = @_;

    if ($c->req->method eq 'POST') {
        if ($c->forward('validate')) {
            my $cart = $c->model('Cart')->search({
                id      => $c->req->params->{'id'},
                shopper => $c->session->{'shopper'},
                type    => CART_TYPE_SAVED
            })->first;

            if ($cart) {
                $cart->destroy;
            } else {
                warn "not cart";
            };

            $c->res->redirect($c->uri_for('/cart/list/'));
        } else {
            $c->forward('list');
        };
    } else {
        $c->res->redirect($c->uri_for('/cart/'));
    };

    return;
};

=head2 list

Displays a list of the current shoppers saved carts/wishlists.

    /cart/list/

=cut

sub list : Local {
    my ($self, $c) = @_;
    $c->stash->{'template'} = 'cart/list';

    if ($c->sessionid && $c->session->{'shopper'}) {
        my $carts = $c->model('Cart')->search({
            shopper => $c->session->{'shopper'},
            type    => CART_TYPE_SAVED
        });

        $c->stash->{'carts'} = $carts;
    };

    return;
};

=head2 load

Loads the shoppers current cart.

    my $cart = $c->forward('load');

=cut

sub load : Private {
    my ($self, $c) = @_;

    if ($c->sessionid && $c->session->{'shopper'}) {
        return $c->model('Cart')->search({
            shopper => $c->session->{'shopper'},
            type    => CART_TYPE_TEMP
        })->first;
    };

    return;
};

=head2 restore

=over

=item Parameters: id

=back

Restores a saved shopping cart into the shoppers current cart during a POST.

    /cart/restore/

=cut

sub restore : Local {
    my ($self, $c) = @_;

    if ($c->req->method eq 'POST') {
        if ($c->forward('validate')) {
            if (my $cart = $c->forward('create')) {
                $cart->restore({
                    id      => $c->req->param('id'),
                    shopper => $c->session->{'shopper'},
                    type    => CART_TYPE_SAVED
                }, $c->req->param('mode') || CART_MODE_APPEND);

                $c->res->redirect($c->uri_for('/cart/'));
            };
        } else {
            $c->forward('list');
        };
    } else {
        $c->res->redirect($c->uri_for('/cart/'));
    };

    return;
};

=head2 save

=over

=item Parameters: name

=back

Saves the current cart with the name specified.

    /cart/save/

=cut

sub save : Local {
    my ($self, $c) = @_;

    if ($c->req->method eq 'POST') {
        if ($c->forward('validate')) {
            if (my $cart = $c->forward('load')) {
                $cart->name($c->req->param('name') || 'My Cart');
                $cart->save;

                $c->res->redirect($c->uri_for('/cart/list/'));
            };
        } else {
            $c->forward('default');
        };
    } else {
        $c->res->redirect($c->uri_for('/cart/'));
    };

    return;
};

=head2 update

=over

=item Parameters: quantity

=back

Updates the specified cart item qith the quantity given.

    /cart/update/

=cut

sub update : Local {
    my ($self, $c) = @_;

    if ($c->req->method eq 'POST') {
        if ($c->forward('validate')) {
            if (my $cart = $c->forward('load')) {
                my $item = $cart->items({
                    id => $c->req->param('id')
                })->first;

                if ($item) {
                    $item->quantity($c->req->param('quantity'));
                };

                $c->res->redirect($c->uri_for('/cart/'));
            };
        } else {
            $c->forward('default');
        };
    } else {
        $c->res->redirect($c->uri_for('/cart/'));
    };

    return;
};

=head2 validate

Validates the current form parameters using the profile in profiles.yml that
matches the current action.

    if ($c->forward('validate')) {
    
    };

=cut

sub validate : Private {
    my ($self, $c) = @_;

    $self->{'validator'}->results->clear;

    my $results = $self->{'validator'}->check(
        $c->req,
        $self->{'profiles'}->{$c->action}
    );

    if ($results->success) {
        return $results;
    } else {
        $c->stash->{'errors'} = $results->messages($c->action);
    };

    return;
};


=head1 AUTHOR

A clever guy

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
