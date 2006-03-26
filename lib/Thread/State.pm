package Thread::State;

use strict;
use warnings;

our $VERSION = '0.05';

require XSLoader;
XSLoader::load('Thread::State', $VERSION);

#################################################
1;
__END__

=head1 NAME

Thread::State -  check threads' state

=head1 SYNOPSIS

 use threads;
 use Thread::State;
 
 my $thr  = threads->new(sub { ... });
 
 while ( $thr->is_running ) {
   ...
 }
 
 if( $thr->in_context ){ # = wantarray
     ...
 }
 
 if ($thr->is_joined) {
   ...
 }
 
 print threads->is_detached; # main thread is detached.

=head1 DESCRIPTION

This module adds some methods to threads which are used to check
threads' state (is detached? joined? finished?) and created context.

L<Thread::Running> is also for the same aim. It hacks threads::new,
threads::join, and threads::detach. On the other hand,
Thread::State peeks at the ithread structures directly.

You must use L<threads> before using Thread::State.

=head1 METHODS

All below methods can be used as class methods. In that case,
they return a current thread's state.

=over 4

=item is_running

The thread is not finished.

=item is_finished

The thread is finished.

=item is_joined

The thread is joined.

=item is_detached

The thread is detached.

=item is_joinable

The thread is joinable (not joined, not detached).

=item in_context

Returns the created context of the thread.
As like C<wantarray>, if void context, returns C<undef>,
list context is true value, and scalar context is false.

=item coderef

Returns the thread coderef which was passed into C<create> or C<new>.
When a thread code is finished with L<threads> core version, the coderef
refcount is made to 0 and destroyed. In that case C<coderef> method
will return C<undef>.


=back


=head1 NOTE

With Perl 5.8.0 on Windows, C<is_joined> and C<is_joinable> may not
work correctly. This is the problem of threads itself.

This problem was fixed by Thread::State 0.04.

=head1 SEE ALSO

L<Thread::Running>,
L<threads>

=head1 AUTHOR

Makamaka Hannyaharamitu, E<lt>makamaka[at]donzoko.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Makamaka Hannyaharamitu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
