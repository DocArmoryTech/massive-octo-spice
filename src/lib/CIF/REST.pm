package CIF::REST;
use Mojo::Base 'Mojolicious';

use strict;
use warnings;

require CIF::Client;
use Data::Dumper;
#use Schema;

use constant {
    SECRET      => $ENV{'SECRET'}       || 'ZOMGZ CHANGE ME!',
    EXPIRATION  => $ENV{'EXPIRATION'}   || (3600*24*7),
    MODE        => $ENV{'MODE'}         || 'development',
    REMOTE      => $ENV{'REMOTE'}       || 'tcp://localhost:' . CIF::DEFAULT_PORT(),
    VERSION     => $ENV{'VERSION'}      || 2,
};

# Connects once for entire application. For real apps, consider using a helper
# that can reconnect on each request if necessary.
#has schema => sub {
#  return Schema->connect('dbi:SQLite:' . ($ENV{TEST_DB} || 'test.db'));
#};

# https://github.com/tempire/mojolicious-plugin-basicauth/blob/master/lib/Mojolicious/Plugin/BasicAuth.pm
# http://daveyshafik.com/archives/35507-mimetypes-and-apis.html
# http://www.troyhunt.com/2014/02/your-api-versioning-is-wrong-which-is.html
# https://developer.github.com/v3/
sub startup {
    my $self = shift;
    
    $self->secrets(SECRET);
    $self->mode(MODE);
    $self->sessions->default_expiration(EXPIRATION);
    
    $self->hook(after_render => sub {
        my ($c, $output, $format) = @_;
        $c->res->headers->append('X-CIF-Media-Type' => 'vnd.cif.'.VERSION());
    });
    
    # http://mojolicio.us/perldoc/Mojolicious/Guides/Rendering#Content-type
    # http://mojolicio.us/perldoc/Mojolicious/Renderer#default_format
    $self->hook(before_routes => sub { ## TODO -- around_action?
        my $c = shift;
        if($c->req->headers->accept =~ /json/ || $c->req->headers->user_agent =~ /curl|wget|^cif/){
            $c->app->renderer->default_format('json');
        } else {
            $c->app->renderer->default_format('html');
        }
    });

    $self->helper(cli => sub {
        CIF::Client->new({
            remote  => REMOTE,
        })
    });
    
    $self->helper(auth => sub {
        my $self = shift;
        
        return 1 if
            $self->param('token');
        }
    );
    
    $self->helper(version => sub {
        my $self = shift;
        my $accept = $self->req->headers->accept();
        my $version = VERSION;
        if($accept =~ /vnd\.cif\.v(\d)/){
            $version = $1;
        }
        return $version;
    });

    my $r = $self->routes;
    
    $r->get('/')->to('help#index')->name('help#index');
    $r->get('/help')->to('help#index')->name('help#index');
    
    my $protected = $r->under( sub {
        my $self = shift;
        return 1 if $self->auth;
        $self->render(json   => { 'message' => 'missing token' }, status => 401 );
        return;
    });
    
    
    $protected->get('/ping')->via('GET')->to('ping#index')->name('ping#index');;
   
    $protected->get('/observables')->to('observables#index')->name('observables#index');
    $protected->put('/observables')->to('observables#create')->name('observables#create');
    $protected->get('/observables/:observable')->to('observables#show')->name('observables#show');
    
    $protected->get('/feeds')->to('feeds#index')->name('feeds#index');
    $protected->put('/feeds')->to('feeds#create')->name('feeds#create');
    $protected->get('/feeds/:feed')->to('feeds#show')->name('feeds#show');

}

1;