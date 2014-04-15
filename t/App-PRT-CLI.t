package t::App::PRT::CLI;
use t::test;
use FindBin;
use File::Basename ();

sub _require : Test(startup => 1) {
    my ($self) = @_;

    use_ok 'App::PRT::CLI';
}

sub instantiate : Tests {
    isa_ok App::PRT::CLI->new, 'App::PRT::CLI';
}

sub _command_name_to_command_class : Tests {
    my $cli = App::PRT::CLI->new;

    is $cli->_command_name_to_command_class('hello'), 'App::PRT::Command::Hello', 'ucfirst';
    is $cli->_command_name_to_command_class('replace_token'), 'App::PRT::Command::ReplaceToken', 'separate by _';
}

sub parse : Tests {
    subtest 'when empty input' => sub {
        my $cli = App::PRT::CLI->new;
        ok $cli->parse;
        isa_ok $cli->command, 'App::PRT::Command::Help', 'default command is help';
        ok ! $cli->collector;
    };

    subtest 'when command specified, not a git directory' => sub {
        my $directory = t::test::prepare_test_code('contain_ignores');
        my $g = mock_guard 'Cwd' => {
            getcwd => "$directory",
        };

        my $cli = App::PRT::CLI->new;
        $cli->parse(qw{replace_token foo bar});
        cmp_deeply $cli->command, isa('App::PRT::Command::ReplaceToken') & methods(
            source_tokens => [ 'foo' ],
            destination_tokens => [ 'bar' ],
        ), 'ReplaceToken command loaded';

        isa_ok $cli->collector, 'App::PRT::Collector::AllFiles';

        # TODO: test $collector->root_directory
        cmp_bag $cli->collector->collect, [
            "$directory/app.psgi",
            "$directory/eg/eg.pl",
            "$directory/lib/Foo.pm",
            "$directory/lib/Foo/Bar.pm",
            "$directory/t/test.t",
        ];
    };

    subtest 'when command specified, git directory' => sub {
        my $directory = t::test::prepare_test_code('dinner');
        t::test::prepare_as_git_repository($directory);
        my $g = mock_guard 'Cwd' => {
            getcwd => "$directory",
        };

        my $cli = App::PRT::CLI->new;
        $cli->parse(qw{replace_token foo bar});
        cmp_deeply $cli->command, isa('App::PRT::Command::ReplaceToken') & methods(
            source_tokens => [ 'foo' ],
            destination_tokens => [ 'bar' ],
        ), 'ReplaceToken command loaded';

        isa_ok $cli->collector, 'App::PRT::Collector::GitDirectory';

        # TODO: test $collector->root_directory
        cmp_bag $cli->collector->collect, [
            "$directory/dinner.pl",
            "$directory/lib/My/Food.pm",
            "$directory/lib/My/Human.pm",
            "$directory/t/001-my-food._t",
            "$directory/t/My-Food._t",
        ];
    };

    subtest 'when source, destination, target files specified' => sub {
        my $cli = App::PRT::CLI->new;
        my $directory = t::test::prepare_test_code('dinner');
        $cli->parse(
            qw{replace_token foo bar},
            qq{$directory/dinner.pl},
            qq{$directory/lib/My/Food.pm},
            qq{$directory/lib/My/Human.pm}
        );
        cmp_deeply $cli->command, isa('App::PRT::Command::ReplaceToken') & methods(
            source_tokens => [ 'foo' ],
            destination_tokens => [ 'bar' ],
        ), 'ReplaceToken command loaded and foo => bar registered';
        cmp_deeply $cli->collector, isa('App::PRT::Collector::Files') & methods(
            collect => [
                qq{$directory/dinner.pl},
                qq{$directory/lib/My/Food.pm},
                qq{$directory/lib/My/Human.pm}
            ],
        ), 'Files collector loaded and files are registered';
    };

    subtest 'when invalid command specified' => sub {
        my $cli = App::PRT::CLI->new;
        ok exception {
            $cli->parse('invalid_comand');
        }, 'died';
    };
}

sub run : Tests {
    subtest "command which doesn't handle files" => sub {
        my $cli = App::PRT::CLI->new;
        my $g = mock_guard 'App::PRT::Command::Help' => {
            execute => sub {
                1;
            },
        };
        $cli->parse('help');
        $cli->run;

        is $g->call_count('App::PRT::Command::Help', 'execute'), 1, 'execute called';
    };

    subtest 'command which handles files' => sub {
        my $directory = t::test::prepare_test_code('hello_world');

        my $cli = App::PRT::CLI->new;
        $cli->parse(qw(replace_token foo bar), "$directory/hello_world.pl");

        my $file;
        my $g = mock_guard 'App::PRT::Command::ReplaceToken' => {
            execute => sub {
                (undef, $file) = @_;
            },
        };

        $cli->run;

        is $g->call_count('App::PRT::Command::ReplaceToken', 'execute'), 1, 'execute called';
        is $file, "$directory/hello_world.pl", 'called with file'
    };
}
