package Mason::Util;
use Carp;
use Data::UUID;
use Fcntl qw( :DEFAULT );
use strict;
use warnings;
use base qw(Exporter);

our @EXPORT_OK = qw(in_perl_db checksum read_file write_file unique_id);

my $Fetch_Flags = O_RDONLY | O_BINARY;
my $Store_Flags = O_WRONLY | O_CREAT | O_BINARY;

# Define an in_perl_db compile-time constant indicating whether we are
# in the Perl debugger. This is used in the object file to
# determine whether to call $m->debug_hook.
#
if ( defined($DB::sub) ) {
    *in_perl_db = sub () { 1 };
}
else {
    *in_perl_db = sub () { 0 };
}

sub read_file {
    my ($file) = @_;

    # Fast slurp, adapted from File::Slurp::read, with unnecessary options removed
    #
    my $buf = "";
    my $read_fh;
    unless ( sysopen( $read_fh, $file, $Fetch_Flags ) ) {
        croak "read_file '$file' - sysopen: $!";
    }
    my $size_left = -s $read_fh;
    while (1) {
        my $read_cnt = sysread( $read_fh, $buf, $size_left, length $buf );
        if ( defined $read_cnt ) {
            last if $read_cnt == 0;
            $size_left -= $read_cnt;
            last if $size_left <= 0;
        }
        else {
            croak "read_file '$file' - sysread: $!";
        }
    }
    return $buf;
}

sub write_file {
    my ( $file, $data, $file_create_mode ) = @_;
    $file_create_mode = oct(666) if !defined($file_create_mode);

    # Fast spew, adapted from File::Slurp::write, with unnecessary options removed
    #
    {
        my $write_fh;
        unless ( sysopen( $write_fh, $file, $Store_Flags, $file_create_mode ) )
        {
            croak "write_file '$file' - sysopen: $!";
        }
        my $size_left = length($data);
        my $offset    = 0;
        do {
            my $write_cnt = syswrite( $write_fh, $data, $size_left, $offset );
            unless ( defined $write_cnt ) {
                croak "write_file '$file' - syswrite: $!";
            }
            $size_left -= $write_cnt;
            $offset += $write_cnt;
        } while ( $size_left > 0 );
    }
}

{

    # For efficiency, use Data::UUID to generate an initial unique id, then suffix it to
    # generate a series of 0x10000 unique ids. Not to be used for hard-to-guess ids, obviously.

    my $uuid;
    my $suffix = 0;

    sub unique_id {
        if ( !$suffix || !defined($uuid) ) {
            my $ug = Data::UUID->new();
            $uuid = $ug->create_hex();
        }
        my $hex = sprintf( '%s%04x', $uuid, $suffix );
        $suffix = ( $suffix + 1 ) & 0xffff;
        return $hex;
    }
}

# Adler32 algorithm
sub checksum {
    my ($str) = @_;
    
    my $s1 = 1;
    my $s2 = 1;
    for my $c (unpack("C*", $str)) {
        $s1 = ($s1 + $c ) % 65521;
        $s2 = ($s2 + $s1) % 65521;
    }
    return ($s2 << 16) + $s1;
}

1;