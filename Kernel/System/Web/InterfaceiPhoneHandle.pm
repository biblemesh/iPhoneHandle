# --
# Kernel/System/Web/InterfaceiPhoneHandle.pm - the agent interface file (incl. auth)
# Copyright (C) 2001-2013 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Web::InterfaceiPhoneHandle;

use strict;
use warnings;

use Kernel::Config;
use Kernel::System::Auth;
use Kernel::System::CustomerUser;
use Kernel::System::DB;
use Kernel::System::Encode;
use Kernel::System::Log;
use Kernel::System::Group;
use Kernel::System::iPhone;
use Kernel::System::JSON;
use Kernel::System::LinkObject;
use Kernel::System::Lock;
use Kernel::System::Main;
use Kernel::System::Queue;
use Kernel::System::Service;
use Kernel::System::SLA;
use Kernel::System::State;
use Kernel::System::Ticket;
use Kernel::System::Time;
use Kernel::System::Type;
use Kernel::System::User;
use Kernel::System::Web::Request;

=head1 NAME

Kernel::System::Web::InterfaceiPhoneHandle - the iPhone Handle web interface

=head1 SYNOPSIS

the global iPhone Handle web interface

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create iPhoneHandle web interface object

    use Kernel::System::Web::InterfaceiPhoneHandle;

    my $InterfaceAgent = Kernel::System::Web::InterfaceiPhoneHandle->new(
        WebRequest => CGI::Fast->new(), # optional, e. g. if fast cgi is used, the CGI object is already provided
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create common objects
    $Self->{ConfigObject} = Kernel::Config->new();
    $Self->{LogObject}    = Kernel::System::Log->new(
        LogPrefix => 'OTRS-iPhoneHandle',
        %{$Self},
    );
    $Self->{EncodeObject} = Kernel::System::Encode->new( %{$Self} );
    $Self->{MainObject}   = Kernel::System::Main->new( %{$Self} );
    $Self->{TimeObject}   = Kernel::System::Time->new( %{$Self} );
    $Self->{ParamObject}  = Kernel::System::Web::Request->new(
        %{$Self},
        WebRequest => $Param{WebRequest} || 0,
    );
    $Self->{DBObject}           = Kernel::System::DB->new( %{$Self} );
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
    $Self->{iPhoneObject}       = Kernel::System::iPhone->new( %{$Self} );

    # get log filename
    $Self->{DebugLogFile} = $Self->{ConfigObject}->Get('iPhone::LogFile') || '';

    return $Self;
}

=item Run()

execute the object

    my $Result = $InterfaceAgent->Run();

Returns:
    $Result = {
        Success => 1,
        Data    => $ArrayOfHashesRef,
    }

Or:
    $Result = $ArrayRef,

Or:
    $Result = {
        Result       => 0,
        ErrorMessage => 'some message',
    }

=cut

sub Run {
    my ($Self) = @_;

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

        $Self->_Log(
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

        return $Self->_Result(
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
            return $Self->_Result(
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
            return $Self->_Result(
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
            return $Self->_Result();
        }

        if ( $User ne $RequiredUser || $Pw ne $RequiredPassword ) {
            $Self->{LogObject}->Log(
                Priority => 'notice',
                Message  => "Auth for user $User failed!",
            );
            return $Self->_Result();
        }
    }

    if ( !$Self->{$Object} && $Object ne 'CustomObject' ) {
        my $Message = "No such Object $Object!";
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => $Message,
        );
        return $Self->_Result(
            {
                Success      => 0,
                ErrorMessage => $Message,
            },
        );
    }

    # check if method exists in objects other than 'CustomObject'
    if (
        ( $Self->{$Object} && !$Self->{$Object}->can($Method) )
        && !$Self->can($Method)
        )
    {
        my $Message = "No such method '$Method' in '$Object'!";
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => $Message,
        );
        return $Self->_Result(
            {
                Success      => 0,
                ErrorMessage => $Message,
            },
        );
    }
    elsif ( $Object eq 'CustomObject' ) {

        # check if method exists in iPhoneObject
        if ( !$Self->{iPhoneObject}->can($Method) ) {
            my $Message = "No such method '$Method' in '$Object'!";
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => $Message,
            );
            return $Self->_Result(
                {
                    Success      => 0,
                    ErrorMessage => $Message,
                },
            );
        }
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
            return $Self->_Result(
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
            return $Self->_Result(
                {
                    Success      => 0,
                    ErrorMessage => $Message,
                },
            );
        }
    }

    # execute iPhoneObject methods
    if ( $Object eq 'CustomObject' || $Object eq 'iPhoneObject' ) {

        my @Result = $Self->{iPhoneObject}->$Method(
            %Param,
            %ParamFixed,
        );
        return $Self->_Result( \@Result );
    }

    # execute other object methods
    else {
        my @Result = $Self->{$Object}->$Method(
            %Param,
            %ParamFixed,
        );
        return $Self->_Result( \@Result );
    }
}

=item _Result()

encodes the result as a JSON object

    my $Result = $InterfaceAgent->_Result(
        $ArrayRef,          #Optional,
    };

OR:
    my $Result = $InterfaceAgent->_Result(
        Success => 1,                    # Optional
        Data    => $ArrayHashRef         # Optional, Mandatory if Succcess is 1
        Message => 'some errror message' # Optional
    );

Returns JSON representation of:
    $Result = {
        Success => 'successful',
        Data    => $ArrayOfHashesRef,
    }

Or JSON represetation of:
    $Result = {
        Result       => 'failes',
        Message => 'some message',
    }

=cut

sub _Result {
    my ( $Self, $Result ) = @_;

    my %ResultProtocol;

    if ($Result) {

        # this method is still needed for other objects than CustomObject
        # this method is also used for backward compatibility of not migrated CustomObject functions
        if ( ref $Result eq 'ARRAY' ) {

            # -1 response means an error
            if ( defined @{$Result}[0] && @{$Result}[0] eq -1 ) {
                $ResultProtocol{Result} = 'failed';

                # get last loged error and set is as the error message
                for my $Key (qw(error notice)) {
                    $ResultProtocol{Message} = $Self->{LogObject}->GetLogEntry(
                        Type => $Key,
                        What => 'Message',
                    );
                    last if $ResultProtocol{Message};
                }
            }

            # otherwise is always successful
            else {
                $ResultProtocol{Result} = 'successful';
                $ResultProtocol{Data}   = $Result;
            }
        }

        # this method will have more control over the error messages
        elsif ( ref $Result eq 'HASH' ) {

            # check for a true value in Success key
            if ( defined $Result->{Success} && $Result->{Success} == 1 ) {
                $ResultProtocol{Result} = 'successful';
                $ResultProtocol{Data}   = $Result->{Data};
            }

            # otherwise is an error
            elsif ( defined $Result->{Success} && !$Result->{Success} ) {
                $ResultProtocol{Result} = 'failed',
                    $ResultProtocol{Message}
                    = $Result->{ErrorMessage}
                    || 'Unknown Error, plase contact system administrator to check OTRS Logs!';
            }
        }

        # success fallback if result is not an ARRAY or HASH
        else {
            $ResultProtocol{Result} = 'successful';
            $ResultProtocol{Data}   = $Result;
        }
    }

    # failed fallback if there was no response
    else {
        $ResultProtocol{Result} = 'failed';

        # get last loged error and set is as the error message
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

        $Self->_Log(
            Direction => 'Outbound',
            Message   => $JSONResult,
            )
    }

    return $JSONResult;
}

=item _Log()

writes to a defined log file

    $InterfaceAgent->_Log(
        Direction => 'Inbound',       # or Outbound
        Message   => 'Some Message',
    };

=cut

sub _Log {
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

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
