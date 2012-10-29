# --
# scripts/test/JSONGateway.t - layout BuildSelection() testscript
# Copyright (C) 2001-2012 OTRS AG, http://otrs.org/
# --
# $Id: JSONGateway.t,v 1.1 2012-10-29 21:59:32 cr Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;
use vars (qw($Self));

use Kernel::Config;
use Kernel::System::JSON;
use Kernel::System::UnitTest::Helper;
use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

# helper object
my $HelperObject = Kernel::System::UnitTest::Helper->new(
    %{$Self},
    UnitTestObject             => $Self,
    RestoreSystemConfiguration => 1,
);

# create other objects
my $ConfigObject = Kernel::Config->new();
my $JSONObject   = Kernel::System::JSON->new( %{$Self} );

my $Home = $ConfigObject->Get('Home');

my $JSONCGI = $Home . '/bin/cgi-bin/json.pl';

my $FileExists;
if ( -e $JSONCGI ) {
    $FileExists = 1;
}

# sanity test
$Self->True(
    $FileExists,
    "$JSONCGI exists in the file system",
);

my $CallJSONCGI = sub {
    my %Param = @_;

    my %JSONParams;
    if ( IsHashRefWithData( $Param{JSONParams} ) ) {
        %JSONParams = %{ $Param{JSONParams} };
    }

    # copy JSON CGI handler
    my $Command = $JSONCGI;

    for my $Item ( keys %JSONParams ) {
        $Command .= " $Item=$JSONParams{$Item}";
    }

    # use Data::Dumper;
    # print STDERR Dumper($Command); #TODO Delete Developers Oputput

    # execute JSON CGI with all parameters
    my $RawResponse = `$Command` || '';

    $Self->IsNot(
        $RawResponse,
        '',
        "JSON CGI - Test $Param{TestName} - response is not empty",
    );

    # JSON response in this mode should be always a 3 lines string, the important result is the
    # line number 3
    my @Response = split /\n/, $RawResponse;

    $Self->Is(
        scalar @Response,
        3,
        "JSON CGI - Test $Param{TestName} - response contains 3 lines",
    );

    $Self->Is(
        $Response[0],
        'Content-Type: text/plain; ',
        "JSON CGI - Test $Param{TestName} - response line 1 match expected results",
    );

    $Self->IsNot(
        $Response[2],
        '',
        "JSON CGI - Test $Param{TestName} - response line 2 is not empty",
    );

    # return line number 3 (position 2 in the array)
    return $Response[2];
};

my $User     = 'root@localhost';
my $Password = 'root';
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

for my $Test (@Tests) {
    my $JSONResponse = $CallJSONCGI->(
        TestName   => $Test->{Name},
        JSONParams => $Test->{JSONParams},
    );

    my $Response = $JSONObject->Decode( Data => $JSONResponse );

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
