# --
# Kernel/System/Web/InterfaceiPhoneHandle.pm - the agent interface file (incl. auth)
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Web::InterfaceiPhoneHandle;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Auth',
    'Kernel::System::JSON',
    'Kernel::System::Log',
    'Kernel::System::Time',
    'Kernel::System::User',
    'Kernel::System::Web::Request',
);

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

    $Kernel::OM->ObjectParamAdd(
        'Kernel::System::Log' => {
            LogPrefix => 'OTRS-iPhoneHandle',
        },
        'Kernel::System::Web::Request' => {
            WebRequest => $Param{WebRequest} || 0,
        },
    );

    # get log filename
    $Self->{DebugLogFile} = $Kernel::OM->Get('Kernel::Config')->Get('iPhone::LogFile') || '';

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

    # get param object
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    # set common variables
    my $User            = $ParamObject->GetParam( Param => 'User' )     || '';
    my $Pw              = $ParamObject->GetParam( Param => 'Password' ) || '';
    my $RequestedObject = $ParamObject->GetParam( Param => 'Object' )   || '';
    my $Method          = $ParamObject->GetParam( Param => 'Method' )   || '';
    my $Data            = $ParamObject->GetParam( Param => 'Data' );
    my $ParamScalar = $Kernel::OM->Get('Kernel::System::JSON')->Decode( Data => $Data );

    my %Param;
    if ($ParamScalar) {
        %Param = %{$ParamScalar};
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # inbound log
    if ( $ConfigObject->Get('iPhone::DebugLog') ) {
        my $Message = 'User=' . $User . '&Password=****' . '&Object=' . $RequestedObject
            . '&Method=' . $Method . '&Data=' . $Data;

        $Self->_Log(
            Direction => 'Inbound',
            Message   => $Message,
        );
    }

    # check needed
    if ( !$User || !$RequestedObject || !$Method ) {
        my $Message = "Need User, Object and Method!";
        $Kernel::OM->Get('Kernel::System::Log')->Log(
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

    # agent Auth
    my %ParamFixed;
    if (1) {
        my $UserLogin = $Kernel::OM->Get('Kernel::System::Auth')->Auth( User => $User, Pw => $Pw );

        if ( !$UserLogin ) {
            my $Message = "Auth for user $User failed!";
            $Kernel::OM->Get('Kernel::System::Log')->Log(
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
        my $UserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
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

    # system Auth
    # This code is not needed and has to be removed!
    else {
        my $RequiredUser     = $ConfigObject->Get('SOAP::User');
        my $RequiredPassword = $ConfigObject->Get('SOAP::Password');

        if (
            !defined $RequiredUser
            || !length $RequiredUser
            || !defined $RequiredPassword || !length $RequiredPassword
            )
        {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => 'SOAP::User or SOAP::Password is empty, SOAP access denied!',
            );

            return $Self->_Result();
        }

        if ( $User ne $RequiredUser || $Pw ne $RequiredPassword ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Auth for user $User failed!",
            );

            return $Self->_Result();
        }
    }

    # change to ObjectManager implies that there are no created objects in $Self
    #     the following is a list of objects that could be originally created
    #     object manager will handle the creation of this objects on the fly
    #
    # not listed objects will not be created, the behavior should be similar than in previous
    #     versions where the object is not created in and it does not exists in $Self
    my %ObjectAlias = (
        ConfigObject       => 'Kernel::Config',
        LogObject          => 'Kernel::System::Log',
        EncodeObject       => 'Kernel::System::Encode',
        MainObject         => 'Kernel::System::Main',
        TimeObject         => 'Kernel::System::Time',
        DBObject           => 'Kernel::System::DB',
        UserObject         => 'Kernel::System::User',
        GroupObject        => 'Kernel::System::Group',
        QueueObject        => 'Kernel::System::Queue',
        ServiceObject      => 'Kernel::System::Service',
        TypeObject         => 'Kernel::System::Type',
        StateObject        => 'Kernel::System::State',
        LockObject         => 'Kernel::System::Lock',
        SLAObject          => 'Kernel::System::SLA',
        CustomerUserObject => 'Kernel::System::CustomerUser',
        TicketObject       => 'Kernel::System::Ticket',
        LinkObject         => 'Kernel::System::LinkObject',
        CustomObject       => 'Kernel::System::iPhone',
        iPhoneObject       => 'Kernel::System::iPhone',
    );

    my $LocalObject;
    if ( $ObjectAlias{$RequestedObject} ) {
        $LocalObject = $Kernel::OM->Get( $ObjectAlias{$RequestedObject} );
    }

    # check if object was created
    if ( !$LocalObject ) {
        my $Message = "No such Object $RequestedObject!";
        $Kernel::OM->Get('Kernel::System::Log')->Log(
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

    # check if method exists in objects
    if ( !$LocalObject->can($Method) && !$Self->can($Method) ) {
        my $Message = "No such method '$Method' in '$RequestedObject'!";
        $Kernel::OM->Get('Kernel::System::Log')->Log(
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

    # check object white list
    my $ObjectWhiteList = $ConfigObject->Get('iPhone::API::Object');
    if ($ObjectWhiteList) {
        if ( !defined $ObjectWhiteList->{$RequestedObject} ) {
            my $Message = "No access to '$RequestedObject'!";
            $Kernel::OM->Get('Kernel::System::Log')->Log(
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
        if (
            $ObjectWhiteList->{$RequestedObject}
            && $Method !~ m{$ObjectWhiteList->{$RequestedObject}}
            )
        {
            my $Message = "No access method '$Method()' from '$RequestedObject'!";
            $Kernel::OM->Get('Kernel::System::Log')->Log(
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

    # cleanup params iPhone application does not send empty values, but same name as parameter as:
    # TicketID => 'TicketID', this values will need to be set as empty, see bug#9752
    PARAMNAME:
    for my $ParamName ( sort keys %Param ) {
        next PARAMNAME if !$Param{$ParamName};
        next PARAMNAME if $Param{$ParamName} ne "$ParamName";
        $Param{$ParamName} = '';
    }

    # execute object methods
    my @Result = $LocalObject->$Method(
        %Param,
        %ParamFixed,
    );

    return $Self->_Result( \@Result );
}

=item _Result()

encodes the result as a JSON object

    my $Result = $InterfaceAgent->_Result(
        $ArrayRef,          #Optional,
    };

OR:
    my $Result = $InterfaceAgent->_Result(
        Success => 1,                    # Optional
        Data    => $ArrayHashRef         # Optional, Mandatory if Success is 1
        Message => 'some error message' # Optional
    );

Returns JSON representation of:
    $Result = {
        Success => 'successful',
        Data    => $ArrayOfHashesRef,
    }

Or JSON representation of:
    $Result = {
        Result       => 'failed',
        Message => 'some message',
    }

=cut

sub _Result {
    my ( $Self, $Result ) = @_;

    my %ResultProtocol;

    # get log object
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ($Result) {

        # this method is still needed for other objects than CustomObject
        # this method is also used for backward compatibility of not migrated CustomObject functions
        if ( ref $Result eq 'ARRAY' ) {

            # -1 response means an error
            if ( defined @{$Result}[0] && @{$Result}[0] eq -1 ) {
                $ResultProtocol{Result} = 'failed';

                # get last logged error and set is as the error message
                KEY:
                for my $Key (qw(error notice)) {
                    $ResultProtocol{Message} = $LogObject->GetLogEntry(
                        Type => $Key,
                        What => 'Message',
                    );
                    last KEY if $ResultProtocol{Message};
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
                    || 'Unknown Error, please contact system administrator to check OTRS Logs!';
            }
        }

        # success fall-back if result is not an ARRAY or HASH
        else {
            $ResultProtocol{Result} = 'successful';
            $ResultProtocol{Data}   = $Result;
        }
    }

    # failed fall-back if there was no response
    else {
        $ResultProtocol{Result} = 'failed';

        # get last logged error and set is as the error message
        KEY:
        for my $Key (qw(error notice)) {
            $ResultProtocol{Message} = $LogObject->GetLogEntry(
                Type => $Key,
                What => 'Message',
            );
            last KEY if $ResultProtocol{Message};
        }
    }

    # set result to a variable for easy log output
    my $JSONResult = $Kernel::OM->Get('Kernel::System::JSON')->Encode( Data => \%ResultProtocol );

    # outbound log
    if ( $Kernel::OM->Get('Kernel::Config')->Get('iPhone::DebugLog') ) {

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

    # open log file
    if ( !open $FH, '>>', $Self->{DebugLogFile} ) {

        # print error screen
        print STDERR "\n";
        print STDERR " >> Can't write $Self->{LogFile}: $! <<\n";
        print STDERR "\n";
        return;
    }

    # write log file
    print $FH '[' . $Kernel::OM->Get('Kernel::System::Time')->CurrentTimestamp() . ']';
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
