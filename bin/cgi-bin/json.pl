#!/usr/bin/perl -w
# --
# bin/cgi-bin/json.pl - json handle
# Copyright (C) 2001-2012 OTRS AG, http://otrs.org/
# --
# $Id: json.pl,v 1.20 2012-06-18 14:55:03 cr Exp $
# --
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU AFFERO General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
# or see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

# use ../../ as lib location
use FindBin qw($Bin);
use lib "$Bin/../..";
use lib "$Bin/../../Kernel/cpan-lib";

use Kernel::Config;
use Kernel::System::Encode;
use Kernel::System::Log;
use Kernel::System::DB;
use Kernel::System::Main;
use Kernel::System::Time;
use Kernel::System::Auth;
use Kernel::System::User;
use Kernel::System::Group;
use Kernel::System::Queue;
use Kernel::System::Service;
use Kernel::System::Type;
use Kernel::System::State;
use Kernel::System::Lock;
use Kernel::System::SLA;
use Kernel::System::CustomerUser;
use Kernel::System::Ticket;
use Kernel::System::LinkObject;
use Kernel::System::JSON;
use Kernel::System::iPhone;

use Kernel::System::Web::Request;

use vars qw($VERSION);
$VERSION = qw($Revision: 1.20 $) [1];

my $Self = Core->new();
print "Content-Type: text/plain; \n";
print "\n";
print $Self->Dispatch();

package Core;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Dispatch {
    my ($Self) = @_;

    # common objects
    $Self->{ConfigObject} = Kernel::Config->new();
    $Self->{EncodeObject} = Kernel::System::Encode->new( %{$Self} );
    $Self->{LogObject}    = Kernel::System::Log->new(
        LogPrefix => 'OTRS-iPhoneHandle',
        %{$Self},
    );
    $Self->{MainObject}         = Kernel::System::Main->new( %{$Self} );
    $Self->{DBObject}           = Kernel::System::DB->new( %{$Self} );
    $Self->{TimeObject}         = Kernel::System::Time->new( %{$Self} );
    $Self->{UserObject}         = Kernel::System::User->new( %{$Self} );
    $Self->{GroupObject}        = Kernel::System::Group->new( %{$Self} );
    $Self->{QueueObject}        = Kernel::System::Queue->new( %{$Self} );
    $Self->{ServiceObject}      = Kernel::System::Service->new( %{$Self} );
    $Self->{TypeObject}         = Kernel::System::Type->new( %{$Self} );
    $Self->{StateObject}        = Kernel::System::State->new( %{$Self} );
    $Self->{LockObject}         = Kernel::System::Lock->new( %{$Self} );
    $Self->{SLAObject}          = Kernel::System::SLA->new( %{$Self} );
    $Self->{CustomerUserObject} = Kernel::System::CustomerUser->new( %{$Self} );
    $Self->{TicketObject}       = Kernel::System::Ticket->new( %{$Self} );
    $Self->{LinkObject}         = Kernel::System::LinkObject->new( %{$Self} );
    $Self->{JSONObject}         = Kernel::System::JSON->new( %{$Self} );
    $Self->{ParamObject}        = Kernel::System::Web::Request->new( %{$Self} );
    $Self->{iPhoneObject}       = Kernel::System::iPhone->new( %{$Self} );

    # get log filename
    $Self->{DebugLogFile} = $Self->{ConfigObject}->Get('iPhone::LogFile') || '';

    # set common variables
    my $User   = $Self->{ParamObject}->GetParam( Param => 'User' )     || '';
    my $Pw     = $Self->{ParamObject}->GetParam( Param => 'Password' ) || '';
    my $Object = $Self->{ParamObject}->GetParam( Param => 'Object' )   || '';
    my $Method = $Self->{ParamObject}->GetParam( Param => 'Method' )   || '';
    my $Data   = $Self->{ParamObject}->GetParam( Param => 'Data' );
    my $ParamScalar = $Self->{JSONObject}->Decode( Data => $Data );

    my %Param;
    if ($ParamScalar) {
        %Param = %{$ParamScalar};
    }

    # inbound log
    if ( $Self->{ConfigObject}->Get('iPhone::DebugLog') ) {
        my $Message = 'User=' . $User . '&Password=****' . '&Object=' . $Object
            . '&Method=' . $Method . '&Data=' . $Data;

        $Self->Log(
            Direction => 'Inbound',
            Message   => $Message,
        );
    }

    # check needed
    if ( !$User || !$Object || !$Method ) {
        my $Message = "Need User, Object and Method!";
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => $Message,
        );

        return $Self->Result(
            {
                Success      => 0,
                ErrorMessage => $Message,
            },
        );
    }

    # agent auth
    my %ParamFixed;
    if (1) {
        my $AuthObject = Kernel::System::Auth->new( %{$Self} );
        my $UserLogin = $AuthObject->Auth( User => $User, Pw => $Pw );

        if ( !$UserLogin ) {
            my $Message = "Auth for user $User failed!";
            $Self->{LogObject}->Log(
                Priority => 'notice',
                Message  => $Message,
            );
            return $Self->Result(
                {
                    Success      => 0,
                    ErrorMessage => $Message,
                },
            );
        }

        # set user id
        my $UserID = $Self->{UserObject}->UserLookup(
            UserLogin => $UserLogin,
        );
        if ( !$UserID ) {
            return $Self->Result(
                {
                    Success      => 0,
                    ErrorMessage => "User $UserLogin not found, UserID can not be set!",
                },
            );
        }

        $ParamFixed{UserID} = $UserID;
    }

    # system auth
    # This code is not needed and has to be removed!
    else {
        my $RequiredUser     = $Self->{ConfigObject}->Get('SOAP::User');
        my $RequiredPassword = $Self->{ConfigObject}->Get('SOAP::Password');

        if (
            !defined $RequiredUser
            || !length $RequiredUser
            || !defined $RequiredPassword || !length $RequiredPassword
            )
        {
            $Self->{LogObject}->Log(
                Priority => 'notice',
                Message  => 'SOAP::User or SOAP::Password is empty, SOAP access denied!',
            );
            return $Self->Result();
        }

        if ( $User ne $RequiredUser || $Pw ne $RequiredPassword ) {
            $Self->{LogObject}->Log(
                Priority => 'notice',
                Message  => "Auth for user $User failed!",
            );
            return $Self->Result();
        }
    }

    if ( !$Self->{$Object} && $Object ne 'CustomObject' ) {
        my $Message = "No such Object $Object!";
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => $Message,
        );
        return $Self->Result(
            {
                Success      => 0,
                ErrorMessage => $Message,
            },
        );
    }

    if ( ( $Self->{$Object} && !$Self->{$Object}->can($Method) ) && !$Self->can($Method) ) {
        my $Message = "No such method '$Method' in '$Object'!";
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => $Message,
        );
        return $Self->Result(
            {
                Success      => 0,
                ErrorMessage => $Message,
            },
        );
    }

    # object white list
    my $ObjectWhiteList = $Self->{ConfigObject}->Get('iPhone::API::Object');
    if ($ObjectWhiteList) {
        if ( !defined $ObjectWhiteList->{$Object} ) {
            my $Message = "No access to '$Object'!";
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => $Message,
            );
            return $Self->Result(
                {
                    Success      => 0,
                    ErrorMessage => $Message,
                },
            );
        }
        if ( $ObjectWhiteList->{$Object} && $Method !~ /$ObjectWhiteList->{$Object}/ ) {
            my $Message = "No access method '$Method()' from '$Object'!";
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => $Message,
            );
            return $Self->Result(
                {
                    Success      => 0,
                    ErrorMessage => $Message,
                },
            );
        }
    }

    # ticket permission check

    if ( $Object eq 'CustomObject' ) {

        # TODO change the way the result is got to accept either hash or array
        my @Result = $Self->{iPhoneObject}->$Method(
            %Param,
            %ParamFixed,
        );
        return $Self->Result( \@Result );
    }
    else {
        my @Result = $Self->{$Object}->$Method(
            %Param,
            %ParamFixed,
        );
        return $Self->Result( \@Result );
    }
}

sub Result {
    my ( $Self, $Result ) = @_;

    my %ResultProtocol;

    if ($Result) {

        # this method is still needed for other objects than CustomObject
        if ( ref $Result eq 'ARRAY' ) {
            if ( @{$Result}[0] eq -1 ) {
                $ResultProtocol{Result} = 'failed';
                for my $Key (qw(error notice)) {
                    $ResultProtocol{Message} = $Self->{LogObject}->GetLogEntry(
                        Type => $Key,
                        What => 'Message',
                    );
                    last if $ResultProtocol{Message};
                }
            }
            else {
                $ResultProtocol{Result} = 'successful';
                $ResultProtocol{Data}   = $Result;
            }
        }

        # TODO change the object call for CustomObject tu support array or hash
        # new result format (to be used within iPhoneHandle functions)
        # only a few functions are using this new method
        elsif ( ref $Result eq 'HASH' ) {
            if ( defined $Result->{Success} && $Result->{Success} == 1 ) {
                $ResultProtocol{Result} = 'successful';
                $ResultProtocol{Data}   = $Result->{Data};
            }
            elsif ( defined $Result->{Success} && !$Result->{Success} ) {
                $ResultProtocol{Result}      = 'failed',
                    $ResultProtocol{Message} = $Result->{ErrorMessage};
            }
        }

        else {
            $ResultProtocol{Result} = 'successful';
            $ResultProtocol{Data}   = $Result;
        }
    }

    else {
        $ResultProtocol{Result} = 'failed';
        for my $Key (qw(error notice)) {
            $ResultProtocol{Message} = $Self->{LogObject}->GetLogEntry(
                Type => $Key,
                What => 'Message',
            );
            last if $ResultProtocol{Message};
        }
    }

    # set result to a variable for easy log output
    my $JSONResult = $Self->{JSONObject}->Encode( Data => \%ResultProtocol );

    # outbound log
    if ( $Self->{ConfigObject}->Get('iPhone::DebugLog') ) {

        $Self->Log(
            Direction => 'Outbound',
            Message   => $JSONResult,
            )
    }

    return $JSONResult;
}

sub Log {
    my ( $Self, %Param ) = @_;

    my $FH;

    # open logfile
    if ( !open $FH, '>>', $Self->{DebugLogFile} ) {

        # print error screen
        print STDERR "\n";
        print STDERR " >> Can't write $Self->{LogFile}: $! <<\n";
        print STDERR "\n";
        return;
    }

    # write log file
    print $FH '[' . $Self->{TimeObject}->CurrentTimestamp() . ']';
    print $FH "[Debug] [$Param{Direction}] $Param{Message}\n";

    # close file handle
    close $FH;
    return 1;
}

1;
