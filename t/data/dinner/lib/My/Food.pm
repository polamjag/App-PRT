package My::Food;
use strict;
use warnings;
$My::Food::VERSION = '0.01';
$My::Food::Foo::GLOBAL_VAR = 'foobar';

sub new {
    my ($class, $name) = @_;

    bless {
        name => $name,
    }, $class;
}

sub name {
    my ($self) = @_;

    $self->{name};
}

1;
