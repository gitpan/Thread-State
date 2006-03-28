use warnings;
use strict;
use Config;


BEGIN {
    if ($Config{'useithreads'}) {
        require threads;
        threads->import;
        require Test::More;
        Test::More->import( tests => 3 );
    }
    else {
        require Test::More;
        Test::More->import(skip_all => "no useithreads");
    }
}


use_ok('Thread::State');

my $thr = threads->new(sub{ sleep 1; });

is($thr->priority, 0);
is($thr->priority(0), 0);

for (threads->list){
    $_->join;
}
