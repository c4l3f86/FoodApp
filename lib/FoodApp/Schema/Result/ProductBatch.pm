package FoodApp::Schema::Result::ProductBatch;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "EncodedColumn");

=head1 NAME

FoodApp::Schema::Result::ProductBatch

=cut

__PACKAGE__->table("product_batch");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 contains

Type: has_many

Related object: L<FoodApp::Schema::Result::Contain>

=cut

__PACKAGE__->has_many(
  "contains",
  "FoodApp::Schema::Result::Contain",
  { "foreign.batch_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-16 10:48:09
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8I8EqeOxnqFmkp45i3WbJw

__PACKAGE__->many_to_many(machines => 'machine_products', 'machine');

# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
