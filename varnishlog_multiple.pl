#!/usr/bin/perl

use strict;
use warnings;

use File::Pid;
use IO::File;
use File::Tail;
use IO::Handle;

$SIG{INT}  = \&cerrar_todo;
$SIG{TERM} = \&cerrar_todo;

my @dominios;
my $log_files;
my $pidfile;
my $varnish_log_feed;
my $error_log;
my $mi_log;


#
# Edit this to your files
# 

my $log_dir          = '/var/log/varnish';
my $apache_sites_dir = '/etc/apache2/sites-enabled';
my $varnish_log_file = '/var/log/varnish/varnishncsa.log';
my $error_log_file   = '/var/log/varnish/error.log';
my $mi_log_file      = '/var/log/varnishlog_multiple.log';

$mi_log = new IO::File $mi_log_file, ">>";
$mi_log->autoflush(1);

print $mi_log "Escribiendo pid file\n";

$pidfile = File::Pid->new( { file => '/var/run/varnishlog_multiple.pid' } );

if ( my $num = $pidfile->running ) {
    die "Ya esta corriendo: $num\n";
}

$pidfile->write;

print $mi_log "Obteniendo dominios.\n";

@dominios = get_dominios($apache_sites_dir);

print $mi_log "Abriendo logs\n";

open_log_files();

print $mi_log "Esperando para abrir el log de varnishncsa\n";

# ya no es necesario pero lo dejo acá por las dudas.
# while (1) {
# 	last if (-e $varnish_log_file);
# }

print $mi_log "Abriendo el log de varnishncsa\n";

$varnish_log_feed = tie *FH, "File::Tail",
    (
    name               => $varnish_log_file,
    ignore_nonexistant => 1,
    maxinterval        => 30,
    tail               => -1,
    );

print $mi_log "Empezando a procesar el log\n";

while (<FH>) {
    my ( $host, @resto ) = split / /, $_;
    $host =~ s/www\.//;
    $host = lc $host;
    if ( exists $log_files->{$host} ) {
        my $para_imprimir = $log_files->{$host};
        print $para_imprimir "@resto";
    }
    else {
        print $error_log "@resto";
    }
}

cerrar_todo();

##
# Subrutinas
##

sub get_dominios {
    my $dir = shift;
    my @tmpdir;
    opendir( DIR, $dir ) or die $!;
    while ( my $file = readdir(DIR) ) {

        # Use a regular expression to ignore files beginning with a period
        next if ( $file =~ m/^\./ );
        next if ( $file =~ m/^0/ );
        $file =~ s/(.*)\.conf$/$1/;
        push @tmpdir, $file;
    }
    closedir(DIR);
    return @tmpdir;
}

# TODO: Hacer esta rutina mas elegante :-/

sub open_log_files {
    foreach my $dominio (@dominios) {
        my $archivo = $log_dir . "/access_" . $dominio . ".log";
        $log_files->{$dominio} = new IO::File $archivo, ">>";
        die "$archivo no pudo ser abierto"
            if ( !defined $log_files->{$dominio} );

        #my $tmp = IO::File->new($archivo,O_WRONLY|O_APPEND);
        #$log_files->{$dominio} = $tmp;
        $log_files->{$dominio}->autoflush(1);
    }
    $error_log = new IO::File $error_log_file, ">>";
    $error_log->autoflush(1);
    print $mi_log "Abiertos los archivos!\n";
}

sub cerrar_todo {
    foreach my $dominio ( keys( %{$log_files} ) ) {
        undef $log_files->{$dominio};
    }
    print $mi_log "Recibida la señal de morir!\n";
    undef $error_log;
    undef $mi_log;
    $pidfile->remove;
    exit(0);
}
