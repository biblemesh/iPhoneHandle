# --
# scripts/test/JSONGateway.t - JSON gateway test script
# Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

## no critic (Modules::RequireExplicitPackage)
use strict;
use warnings;
use utf8;
use vars (qw($Self));

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

# get config object
my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

# get remote host with some precautions for certain unit test systems
my $Host;

my $FQDN = $ConfigObject->Get('FQDN');

# try to resolve FQDN host
if ( $FQDN ne 'yourhost.example.com' && gethostbyname($FQDN) ) {
    $Host = $FQDN;
}

# try to resolve localhost instead
if ( !$Host && gethostbyname('localhost') ) {
    $Host = 'localhost';
}

# use hard-coded localhost IP address
if ( !$Host ) {
    $Host = '127.0.0.1';
}

# prepare config
my $URL =
    $ConfigObject->Get('HttpType')
    . '://'
    . $Host
    . '/'
    . $ConfigObject->Get('ScriptAlias')
    . 'json.pl';

my $CallJSONCGI = sub {
    my %Param = @_;

    my %JSONParams;
    if ( IsHashRefWithData( $Param{JSONParams} ) ) {
        %JSONParams = %{ $Param{JSONParams} };
    }

    # copy JSON CGI handler
    my $JSONUrl = $URL . '?';

    for my $Item ( sort keys %JSONParams ) {
        $JSONUrl .= "$Item=$JSONParams{$Item};";
    }

    my %Response = $Kernel::OM->Get('Kernel::System::WebUserAgent')->Request(
        URL => $JSONUrl,
    );

    $Self->Is(
        $Response{Status},
        '200 OK',
        "JSON CGI - Test $Param{TestName} - response is 200 OK",
    );

    return $Response{Content};
};

#get helper object
my $HelperObject = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

# create test user
my $User = $HelperObject->TestUserCreate(
    Groups => ['users'],
);
my $Password = $User;

my $RandomID = $HelperObject->GetRandomID();

my @Tests = (
    {
        Name       => 'Empty params',
        JSONParams => {},
        Success    => 0,
    },
    {
        Name       => 'Empty user',
        JSONParams => {
            User     => '',
            Password => $Password,
            Object   => 'CustomObject',
            Method   => 'VersionGet',
        },
        Success => 0,
    },
    {
        Name       => 'Empty password',
        JSONParams => {
            User     => $User,
            Password => '',
            Object   => 'CustomObject',
            Method   => 'VersionGet',
        },
        Success => 0,
    },
    {
        Name       => 'Missing password',
        JSONParams => {
            User   => $User,
            Object => 'CustomObject',
            Method => 'VersionGet',
        },
        Success => 0,
    },
    {
        Name       => 'Missing user',
        JSONParams => {
            Password => $Password,
            Object   => 'CustomObject',
            Method   => 'VersionGet',
        },
        Success => 0,
    },
    {
        Name       => 'Wrong user',
        JSONParams => {
            User     => 'NotExisting' . $RandomID,
            Password => $Password,
            Object   => 'CustomObject',
            Method   => 'VersionGet',
        },
        Success => 0,
    },
    {
        Name       => 'Wrong password',
        JSONParams => {
            User     => $User,
            Password => 'NotExisting' . $RandomID,
            Object   => 'CustomObject',
            Method   => 'VersionGet',
        },
        Success => 0,
    },
    {
        Name       => 'Missing object',
        JSONParams => {
            User     => $User,
            Password => $Password,
            Method   => 'VersionGet',
        },
        Success => 0,
    },
    {
        Name       => 'Missing method',
        JSONParams => {
            User     => $User,
            Password => $Password,
            Object   => 'CustomObject',
        },
        Success => 0,
    },
    {
        Name       => 'Wrong Object',
        JSONParams => {
            User     => $User,
            Password => $Password,
            Object   => 'MyObject',
            Method   => 'TicketGet',
        },
        Success => 0,
    },
    {
        Name       => 'Blacklist Object',
        JSONParams => {
            User     => $User,
            Password => $Password,
            Object   => 'ServiceObject',
            Method   => 'ServiceGet',
        },
        Success => 0,
    },
    {
        Name       => 'Whitelist Object, Blacklist Method',
        JSONParams => {
            User     => $User,
            Password => $Password,
            Object   => 'TicketObject',
            Method   => 'TicketGet',
        },
        Success => 0,
    },
    {
        Name       => 'Wrong Method DBObject',
        JSONParams => {
            User     => $User,
            Password => $Password,
            Object   => 'DBObject',
            Method   => 'NotExistentGet',
        },
        Success => 0,
    },
    {
        Name       => 'Wrong Method CustomObject',
        JSONParams => {
            User     => $User,
            Password => $Password,
            Object   => 'CustomObject',
            Method   => 'NotExistentGet',
        },
        Success => 0,
    },
    {
        Name       => 'Missing Parameters CustomObject',
        JSONParams => {
            User     => $User,
            Password => $Password,
            Object   => 'CustomObject',
            Method   => 'CustomerIDGet',
        },
        Success => 0,
    },
    {
        Name       => 'Correct (Without Parameters) CustomObject',
        JSONParams => {
            User     => $User,
            Password => $Password,
            Object   => 'CustomObject',
            Method   => 'VersionGet',
        },
        Success => 1,
    },

);

# get JSON object
my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

for my $Test (@Tests) {
    my $JSONResponse = $CallJSONCGI->(
        TestName   => $Test->{Name},
        JSONParams => $Test->{JSONParams},
    );

    my $Response = $JSONObject->Decode( Data => ${$JSONResponse} );

    $Self->Is(
        ref $Response,
        'HASH',
        "JSON CGI - Test $Test->{Name} - decoded response is a Hash Reference",
    );

    if ( $Test->{Success} ) {

    }
    else {
        $Self->Is(
            $Response->{Result},
            'failed',
            "JSON CGI - Test $Test->{Name} - decoded response result is false",
        );
        $Self->IsNot(
            $Response->{Message},
            '',
            "JSON CGI - Test $Test->{Name} - decoded response message is not empty",
        );
    }
}
1;
