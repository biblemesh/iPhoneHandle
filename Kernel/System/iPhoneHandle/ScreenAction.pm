# --
# Kernel/System/iPhoneHandle/ScreenAction.pm - Screen Action base class
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::iPhoneHandle::ScreenAction;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::CheckItem',
    'Kernel::System::CustomerUser',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Log',
    'Kernel::System::Queue',
    'Kernel::System::State',
    'Kernel::System::Ticket',
    'Kernel::System::Time',
    'Kernel::System::User',
);

=head1 NAME

Kernel::System::iPhoneHandle::ScreenAction - sub module of Kernel::System::iPhoneHandle

=head1 SYNOPSIS

ScreenAction common functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ScreenActions()
Performs a ticket action (Actions include Phone, Note, Close, Compose or Move)

Phone   (New phone ticket)
Note    (Add a note to a Ticket)
Close   (Close a ticket)
Compose (Reply or response a ticket)
Move    (Change ticket queue)

The arguments taken depend on the results of ScreenConfig()

The result is the TicketID for Action Phone or ArticleID for the other actions

    my @Result = $iPhoneObject->ScreenActions(
        Action              => "Phone",
        Subject             => "iPhone Ticket",
        CustomerID          => "otrs",
        Body                => "My first iPhone ticket",
        CustomerUserLogin   => "Aayla",
        TimeUnits           => 123,
        QueueID             => 3,
        OwnerID             => 23,
        ResponsilbeID       => 45,
        StateID             => 4,
        PendingDate         =>"2010-07-09 23:54:18",
        PriorityID          => 1,
        DyanmicField_NameX  => 'some value',
        UserID              => 1,
    );

    # a result could be

    @Result = ( 224 );

=cut

sub ScreenActions {
    my ( $Self, %Param ) = @_;

    my %UserPreferences = $Kernel::OM->Get('Kernel::System::User')->GetPreferences(
        UserID => $Param{UserID},
    );

    if (
        $Kernel::OM->Get('Kernel::Config')->Get('TimeZoneUser')
        && $UserPreferences{UserTimeZone}
        )
    {
        $Param{UserTimeZone} = $UserPreferences{UserTimeZone} || 0;
    }

    # make sure UserTimeZone param is defined
    $Param{UserTimeZone} //= 0;

    if ( $Param{Action} ) {
        my $Result;
        if ( $Param{Action} eq 'Phone' ) {
            $Result = $Self->_TicketPhoneNew(%Param);
            if ($Result) {
                return $Result;
            }
            return -1;
        }
        if ( $Param{Action} eq 'Note' || $Param{Action} eq 'Close' ) {
            $Result = $Self->_TicketCommonActions(%Param);
            if ($Result) {
                return $Result;
            }
            return -1;
        }
        if ( $Param{Action} eq 'Compose' ) {
            $Result = $Self->_TicketCompose(%Param);
            if ($Result) {
                return $Result;
            }
            return -1;
        }
        if ( $Param{Action} eq 'Move' ) {
            $Result = $Self->_TicketMove(%Param);
            if ($Result) {
                return $Result;
            }
            return -1;
        }
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Action undefined! expected Phone, Note, Close, Compose or Move, '
                . 'but ' . $Param{Action} . ' found',
        );
        return -1;
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'No Action given! Please contact the admin.',
        );
        return -1;
    }
}

sub _TicketPhoneNew {
    my ( $Self, %Param ) = @_;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    $Self->{Config} = $ConfigObject->Get('iPhone::Frontend::AgentTicketPhone');

    my %StateData = ();

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    if ( $Param{StateID} ) {
        %StateData = $Kernel::OM->Get('Kernel::System::State')->StateGet(
            ID => $Param{StateID},
        );
    }

    # transform pending time, time stamp based on user time zone
    if ( IsStringWithData( $Param{PendingDate} ) ) {
        $Param{PendingDate} = $Self->_TransformDateSelection(
            TimeStamp    => $Param{PendingDate},
            UserTimeZone => $Param{UserTimeZone},
        );
    }

    # get dynamic field config for the screen
    $Self->{DynamicFieldFilter} = $Self->{Config}->{DynamicField};

    # get the dynamic fields for ticket object
    $Self->{DynamicField} = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => [ 'Ticket', 'Article' ],
        FieldFilter => $Self->{DynamicFieldFilter} || {},
    );

    my %DynamicFieldValues;

    # get dynamic field backend object
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # cycle trough the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
        next DYNAMICFIELD if !IsHashRefWithData( $DynamicFieldConfig->{Config} );
        next DYNAMICFIELD if !$DynamicFieldConfig->{Name};

        # skip all dynamic fields that are not designed render in iPhone App
        my $IsIPhoneCapable = $DynamicFieldBackendObject->HasBehavior(
            DynamicFieldConfig => $DynamicFieldConfig,
            Behavior           => 'IsIPhoneCapable',
        );
        next DYNAMICFIELD if !$IsIPhoneCapable;

        # extract the dynamic field value form parameters
        $DynamicFieldValues{ $DynamicFieldConfig->{Name} }
            = $DynamicFieldBackendObject->IPhoneFieldValueGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            TransformDates     => 1,
            %Param,
            );

        # perform validation of the data
        my $ValidationResult = $DynamicFieldBackendObject->IPhoneFieldValueValidate(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
            Mandatory => $Self->{Config}->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
        );

        if ( !IsHashRefWithData($ValidationResult) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Could not perform validation on field $DynamicFieldConfig->{Label}!",
            );
            return;
        }

        # propagate validation error
        if ( $ValidationResult->{ServerError} ) {

            my $ErrorMessage = $ValidationResult->{ErrorMessage}
                || "Dynamic field $DynamicFieldConfig->{Label} invalid";

            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => $ErrorMessage,
            );
            return;
        }
    }

    my $CustomerUser = $Param{CustomerUserLogin};
    my $CustomerID = $Param{CustomerID} || '';

    # re-wrap body if exists
    if ( $ConfigObject->Get('Frontend::RichText') && $Param{Body} ) {
        $Param{Body}
            =~ s/(^>.+|.{4,$ConfigObject->Get('Ticket::Frontend::TextAreaNote')})(?:\s|\z)/$1\n/gm;
    }

    # get time object
    my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

    # check pending date
    if ( $StateData{TypeName} && $StateData{TypeName} =~ /^pending/i ) {
        if ( !$TimeObject->TimeStamp2SystemTime( String => $Param{PendingDate} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Date invalid',
            );
            return;
        }
        if (
            $TimeObject->TimeStamp2SystemTime( String => $Param{PendingDate} )
            < $TimeObject->SystemTime()
            )
        {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Date invalid',
            );
            return;
        }
    }

    # get customer user  object
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

    #get customer info
    my %CustomerUserData = $CustomerUserObject->CustomerUserDataGet(
        User => $CustomerUser,
    );
    my %CustomerUserList = $CustomerUserObject->CustomerSearch(
        UserLogin => $CustomerUser,
    );
    my $From;
    if (%CustomerUserList) {
        for ( sort keys %CustomerUserList ) {

            if ( $Param{CustomerUserLogin} eq $_ ) {
                $From = $CustomerUserList{$_}
            }
            else {
                $From = $CustomerUser;
            }
        }
    }
    else {
        $From = $CustomerUser;
    }

    # get check item object
    my $CheckItemObject = $Kernel::OM->Get('Kernel::System::CheckItem');

    # check email address
    for my $Email ( Mail::Address->parse( $CustomerUserData{UserEmail} ) ) {
        if ( !$CheckItemObject->CheckEmail( Address => $Email->address() ) ) {
            my $ServerError = $CheckItemObject->CheckError();
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Error on field \"From\"  \n $ServerError",
            );
            return;
        }
    }
    if ( !$Param{CustomerUserLogin} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'From invalid: From is empty',
        );
        return;
    }
    if ( !$Param{Subject} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Subject invalid: Subject is empty',
        );
        return;
    }
    if ( !$Param{QueueID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Destination invalid: Destination queue is empty',
        );
        return;
    }
    if (
        $ConfigObject->Get('Ticket::Service')
        && $Param{SLAID}
        && !$Param{ServiceID}
        )
    {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Service invalid: no service selected',
        );
        return;
    }

    # create new ticket, do db insert
    my $TicketID = $TicketObject->TicketCreate(
        Title        => $Param{Subject},
        QueueID      => $Param{QueueID},
        Subject      => $Param{Subject},
        Lock         => 'unlock',
        TypeID       => $Param{TypeID},
        ServiceID    => $Param{ServiceID},
        SLAID        => $Param{SLAID},
        StateID      => $Param{StateID},
        PriorityID   => $Param{PriorityID},
        OwnerID      => 1,
        CustomerNo   => $CustomerID,
        CustomerUser => $CustomerUser,
        UserID       => $Param{UserID},
    );
    if ( !$TicketID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Error: No ticket created! Please contact admin',
        );
        return;
    }

    # set ticket dynamic fields
    # cycle trough the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
        next DYNAMICFIELD if $DynamicFieldConfig->{ObjectType} ne 'Ticket';

        # skip all dynamic fields that are not designed render in iPhone App
        my $IsIPhoneCapable = $DynamicFieldBackendObject->HasBehavior(
            DynamicFieldConfig => $DynamicFieldConfig,
            Behavior           => 'IsIPhoneCapable',
        );
        next DYNAMICFIELD if !$IsIPhoneCapable;

        # set the value
        my $Success = $DynamicFieldBackendObject->ValueSet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ObjectID           => $TicketID,
            Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
            UserID             => $Param{UserID},
        );
    }

    my $MimeType = 'text/plain';

    # check if new owner is given (then send no agent notify)
    my $NoAgentNotify = 0;
    if ( $Param{OwnerID} ) {
        $NoAgentNotify = 1;
    }
    my $QueueName
        = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup( QueueID => $Param{QueueID} );

    my $ArticleID = $TicketObject->ArticleCreate(
        NoAgentNotify => $NoAgentNotify,
        TicketID      => $TicketID,
        ArticleType   => $Self->{Config}->{ArticleTypeDefault},
        SenderType    => $Self->{Config}->{SenderType},
        From          => $From,
        To            => $QueueName,
        Subject       => $Param{Subject},
        Body          => $Param{Body},
        MimeType      => $MimeType,

        # iPhone must send info in current charset
        Charset          => $ConfigObject->Get('DefaultCharset'),
        UserID           => $Param{UserID},
        HistoryType      => $Self->{Config}->{HistoryType},
        HistoryComment   => $Self->{Config}->{HistoryComment} || '%%',
        AutoResponseType => 'auto reply',
        OrigHeader       => {
            From    => $From,
            To      => $QueueName,
            Subject => $Param{Subject},
            Body    => $Param{Body},
        },
        Queue => $QueueName,
    );

    if ($ArticleID) {

        # set ticket dynamic fields
        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
            next DYNAMICFIELD if $DynamicFieldConfig->{ObjectType} ne 'Article';

            # skip all dynamic fields that are not designed render in iPhone App
            my $IsIPhoneCapable = $DynamicFieldBackendObject->HasBehavior(
                DynamicFieldConfig => $DynamicFieldConfig,
                Behavior           => 'IsIPhoneCapable',
            );
            next DYNAMICFIELD if !$IsIPhoneCapable;

            # set the value
            my $Success = $DynamicFieldBackendObject->ValueSet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $ArticleID,
                Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
                UserID             => $Param{UserID},
            );
        }

        # set owner (if new user id is given)
        if ( $Param{OwnerID} ) {
            $TicketObject->TicketOwnerSet(
                TicketID  => $TicketID,
                NewUserID => $Param{OwnerID},
                UserID    => $Param{UserID},
            );

            # set lock
            $TicketObject->TicketLockSet(
                TicketID => $TicketID,
                Lock     => 'lock',
                UserID   => $Param{UserID},
            );
        }

        # else set owner to current agent but do not lock it
        else {
            $TicketObject->TicketOwnerSet(
                TicketID           => $TicketID,
                NewUserID          => $Param{UserID},
                SendNoNotification => 1,
                UserID             => $Param{UserID},
            );
        }

        # set responsible (if new user id is given)
        if ( $Param{ResponsibleID} ) {
            $TicketObject->TicketResponsibleSet(
                TicketID  => $TicketID,
                NewUserID => $Param{ResponsibleID},
                UserID    => $Param{UserID},
            );
        }

        # time accounting
        if ( $Param{TimeUnits} ) {
            $TicketObject->TicketAccountTime(
                TicketID  => $TicketID,
                ArticleID => $ArticleID,
                TimeUnit  => $Param{TimeUnits},
                UserID    => $Param{UserID},
            );
        }

        # should I set an unlock?
        my %StateData = $Kernel::OM->Get('Kernel::System::State')->StateGet(
            ID => $Param{StateID}
        );
        if ( $StateData{TypeName} =~ /^close/i ) {
            $TicketObject->TicketLockSet(
                TicketID => $TicketID,
                Lock     => 'unlock',
                UserID   => $Param{UserID},
            );
        }

        # set pending time
        elsif ( $StateData{TypeName} =~ /^pending/i ) {

            # set pending time
            $TicketObject->TicketPendingTimeSet(
                UserID   => $Param{UserID},
                TicketID => $TicketID,
                String   => $Param{PendingDate},
            );
        }
        return int $TicketID;
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Error: no article was created! Please contact the admin',
        );
        return;
    }
}

sub _TicketCommonActions {
    my ( $Self, %Param ) = @_;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    $Self->{Config}
        = $ConfigObject->Get( 'iPhone::Frontend::AgentTicket' . $Param{Action} );

    my %StateData = ();

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    if ( $Param{StateID} ) {
        %StateData = $Kernel::OM->Get('Kernel::System::State')->StateGet(
            ID => $Param{StateID},
        );
    }

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'No TicketID is given! Please contact the admin.',
        );
        return;
    }

    # check permissions
    my $Access = $TicketObject->TicketPermission(
        Type     => $Self->{Config}->{Permission},
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
    );

    # error screen, don't show ticket
    if ( !$Access ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "You need $Self->{Config}->{Permission} permissions!",
        );
        return;
    }

    my %Ticket = $TicketObject->TicketGet( TicketID => $Param{TicketID} );

    # get lock state
    if ( $Self->{Config}->{RequiredLock} ) {
        my $Locked = $TicketObject->TicketLockGet( TicketID => $Param{TicketID} );

        if ( !$Locked ) {
            $TicketObject->TicketLockSet(
                TicketID => $Param{TicketID},
                Lock     => 'lock',
                UserID   => $Param{UserID},
            );
            my $Success = $TicketObject->TicketOwnerSet(
                TicketID  => $Param{TicketID},
                UserID    => $Param{UserID},
                NewUserID => $Param{UserID},
            );
        }
        else {
            my $AccessOk = $TicketObject->OwnerCheck(
                TicketID => $Param{TicketID},
                OwnerID  => $Param{UserID},
            );
            if ( !$AccessOk ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => 'Sorry, you need to be the owner to do this action! '
                        . 'Please change the owner first.',
                );
                return;
            }
        }
    }

    # transform pending time, time stamp based on user time zone
    if ( IsStringWithData( $Param{PendingDate} ) ) {
        $Param{PendingDate} = $Self->_TransformDateSelection(
            TimeStamp    => $Param{PendingDate},
            UserTimeZone => $Param{UserTimeZone},
        );
    }

    # get dynamic field config for the screen
    $Self->{DynamicFieldFilter} = $Self->{Config}->{DynamicField};

    # get the dynamic fields for ticket object
    $Self->{DynamicField} = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => [ 'Ticket', 'Article' ],
        FieldFilter => $Self->{DynamicFieldFilter} || {},
    );

    my %DynamicFieldValues;

    # get dynamic field backend object
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # cycle trough the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
        next DYNAMICFIELD if !IsHashRefWithData( $DynamicFieldConfig->{Config} );
        next DYNAMICFIELD if !$DynamicFieldConfig->{Name};

        # skip all dynamic fields that are not designed render in iPhone App
        my $IsIPhoneCapable = $DynamicFieldBackendObject->HasBehavior(
            DynamicFieldConfig => $DynamicFieldConfig,
            Behavior           => 'IsIPhoneCapable',
        );
        next DYNAMICFIELD if !$IsIPhoneCapable;

        # extract the dynamic field value form parameters
        $DynamicFieldValues{ $DynamicFieldConfig->{Name} }
            = $DynamicFieldBackendObject->IPhoneFieldValueGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            TransformDates     => 1,
            %Param,
            );

        # perform validation of the data
        my $ValidationResult = $DynamicFieldBackendObject->IPhoneFieldValueValidate(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
            Mandatory => $Self->{Config}->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
        );

        if ( !IsHashRefWithData($ValidationResult) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Could not perform validation on field $DynamicFieldConfig->{Label}!",
            );
            return;
        }

        # propagate validation error
        if ( $ValidationResult->{ServerError} ) {

            my $ErrorMessage = $ValidationResult->{ErrorMessage}
                || "Dynamic field $DynamicFieldConfig->{Label} invalid";

            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => $ErrorMessage,
            );
            return;
        }
    }

    # re-wrap body if no rich text is used
    if ( $Param{Body} ) {
        my $Size = $ConfigObject->Get('Ticket::Frontend::TextAreaNote') || 70;
        $Param{Body} =~ s/(^>.+|.{4,$Size})(?:\s|\z)/$1\n/gm;
    }

    # get time object
    my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

    # check pending date
    if ( $StateData{TypeName} && $StateData{TypeName} =~ /^pending/i ) {
        if ( !$TimeObject->TimeStamp2SystemTime( String => $Param{PendingDate} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Date invalid',
            );
            return;
        }
        if (
            $TimeObject->TimeStamp2SystemTime( String => $Param{PendingDate} )
            < $TimeObject->SystemTime()
            )
        {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Date invalid',
            );
            return;
        }
    }

    if ( $Self->{Config}->{Note} ) {

        # check subject
        if ( !$Param{Subject} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Subject Invalid: the Subject is empty!',
            );
            return;
        }

        # check body
        if ( !$Param{Body} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Body Invalid: the Body is empty!',
            );
            return;
        }
    }

    #check if Title
    if ( !$Param{Title} ) {
        my %TicketData = $TicketObject->TicketGet(
            TicketID => $Param{TicketID},
            UserID   => $Param{UserID},
        );

        $Param{Title} = $TicketData{Title};
    }

    # set new title
    if ( $Self->{Config}->{Title} ) {
        if ( defined $Param{Title} ) {
            $TicketObject->TicketTitleUpdate(
                Title    => $Param{Title},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
        }
    }

    # set new type
    if ( $ConfigObject->Get('Ticket::Type') && $Self->{Config}->{TicketType} ) {
        if ( $Param{TypeID} ) {
            $TicketObject->TicketTypeSet(
                TypeID   => $Param{TypeID},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
        }
    }

    # set new service
    if ( $ConfigObject->Get('Ticket::Service') && $Self->{Config}->{Service} ) {
        if ( defined $Param{ServiceID} ) {
            $TicketObject->TicketServiceSet(
                ServiceID      => $Param{ServiceID},
                TicketID       => $Param{TicketID},
                CustomerUserID => $Ticket{CustomerUserID},
                UserID         => $Param{UserID},
            );
        }
        if ( defined $Param{SLAID} ) {
            $TicketObject->TicketSLASet(
                SLAID    => $Param{SLAID},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
        }
    }

    # set new owner
    my @NotifyDone;
    if ( $Self->{Config}->{Owner} ) {
        my $BodyText = $Param{Body} || '';
        if ( $Param{OwnerID} ) {
            $TicketObject->TicketLockSet(
                TicketID => $Param{TicketID},
                Lock     => 'lock',
                UserID   => $Param{UserID},
            );
            my $Success = $TicketObject->TicketOwnerSet(
                TicketID  => $Param{TicketID},
                UserID    => $Param{UserID},
                NewUserID => $Param{OwnerID},
                Comment   => $BodyText,
            );

            # remember to not notify owner twice
            if ( $Success && $Success eq 1 ) {
                push @NotifyDone, $Param{OwnerID};
            }
        }
    }

    # set new responsible
    if ( $Self->{Config}->{Responsible} ) {
        if ( $Param{ResponsibleID} ) {
            my $BodyText = $Param{Body} || '';
            my $Success = $TicketObject->TicketResponsibleSet(
                TicketID  => $Param{TicketID},
                UserID    => $Param{UserID},
                NewUserID => $Param{ResponsibleID},
                Comment   => $BodyText,
            );

            # remember to not notify responsible twice
            if ( $Success && $Success eq 1 ) {
                push @NotifyDone, $Param{ResponsibleID};
            }
        }
    }

    # add note
    my $ArticleID = '';
    if ( $Self->{Config}->{Note} || $Param{Defaults} ) {
        my $MimeType = 'text/plain';

        my %User = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
            UserID => $Param{UserID},
        );

        my $From = "$User{UserFirstname} $User{UserLastname} <$User{UserEmail}>";

        $ArticleID = $TicketObject->ArticleCreate(
            TicketID   => $Param{TicketID},
            SenderType => 'agent',
            From       => $From,
            MimeType   => $MimeType,

            # iPhone must send info in current charset
            Charset        => $ConfigObject->Get('DefaultCharset'),
            UserID         => $Param{UserID},
            HistoryType    => $Self->{Config}->{HistoryType},
            HistoryComment => $Self->{Config}->{HistoryComment},

            #                ForceNotificationToUserID       => \@NotifyUserIDs,
            ExcludeMuteNotificationToUserID => \@NotifyDone,
            %Param,
        );

        if ( !$ArticleID ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Error: no article was created! Please contact the admin.',
            );
            return;
        }

        # time accounting
        if ( $Param{TimeUnits} ) {
            $TicketObject->TicketAccountTime(
                TicketID  => $Param{TicketID},
                ArticleID => $ArticleID,
                TimeUnit  => $Param{TimeUnits},
                UserID    => $Param{UserID},
            );
        }

        # set dynamic fields
        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            # set the object ID (TicketID or ArticleID) depending on the field configuration
            my $ObjectID
                = $DynamicFieldConfig->{ObjectType} eq 'Article' ? $ArticleID : $Param{TicketID};

            # set the value
            my $Success = $DynamicFieldBackendObject->ValueSet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $ObjectID,
                Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
                UserID             => $Param{UserID},
            );
        }

        # set priority
        if ( $Self->{Config}->{Priority} && $Param{PriorityID} ) {
            $TicketObject->TicketPrioritySet(
                TicketID   => $Param{TicketID},
                PriorityID => $Param{PriorityID},
                UserID     => $Param{UserID},
            );
        }

        # set state
        if ( $Self->{Config}->{State} && $Param{StateID} ) {
            $TicketObject->TicketStateSet(
                TicketID => $Param{TicketID},
                StateID  => $Param{StateID},
                UserID   => $Param{UserID},
            );

            # unlock the ticket after close
            my %StateData = $Kernel::OM->Get('Kernel::System::State')->StateGet(
                ID => $Param{StateID},
            );

            # set unlock on close state
            if ( $StateData{TypeName} =~ /^close/i ) {
                $TicketObject->TicketLockSet(
                    TicketID => $Param{TicketID},
                    Lock     => 'unlock',
                    UserID   => $Param{UserID},
                );
            }

            # set pending time on pending state
            elsif ( $StateData{TypeName} =~ /^pending/i ) {

                # set pending time
                $TicketObject->TicketPendingTimeSet(
                    UserID   => $Param{UserID},
                    TicketID => $Param{TicketID},
                    String   => $Param{PendingDate},
                );
            }
        }
    }

    else {

        # fill-up configured default vars
        if ( !defined $Param{Body} && $Self->{Config}->{Body} ) {
            $Param{Body} = $Self->{Config}->{Body};
        }
        if ( !defined $Param{Subject} && $Self->{Config}->{Subject} ) {
            $Param{Subject} = $Self->{Config}->{Subject};
        }

        my $Result = $Self->_TicketCommonActions(
            %Param,
            Defaults => 1,
        );
        return $Result;
    }
    return $ArticleID;
}

sub _TicketCompose {
    my ( $Self, %Param ) = @_;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    $Self->{Config}
        = $ConfigObject->Get('iPhone::Frontend::AgentTicketCompose');

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'No TicketID is given! Please contact the admin.',
        );
        return;
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # check permissions
    my $Access = $TicketObject->TicketPermission(
        Type     => $Self->{Config}->{Permission},
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
    );

    # error screen, don't show ticket
    if ( !$Access ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "You need $Self->{Config}->{Permission} permissions!",
        );
        return;
    }
    my %Ticket = $TicketObject->TicketGet( TicketID => $Param{TicketID} );

    # get lock state
    if ( $Self->{Config}->{RequiredLock} ) {
        my $Locked = $TicketObject->TicketLockGet( TicketID => $Param{TicketID} );
        if ( !$Locked ) {
            $TicketObject->TicketLockSet(
                TicketID => $Param{TicketID},
                Lock     => 'lock',
                UserID   => $Param{UserID},
            );

            my $Success = $TicketObject->TicketOwnerSet(
                TicketID  => $Param{TicketID},
                UserID    => $Param{UserID},
                NewUserID => $Param{UserID},
            );
        }
        else {
            my $AccessOk = $TicketObject->OwnerCheck(
                TicketID => $Param{TicketID},
                OwnerID  => $Param{UserID},
            );
            if ( !$AccessOk ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Sorry, you need to be the owner to do this action! "
                        . "Please change the owner first.",
                );
                return;
            }
        }
    }

    # transform pending time, time stamp based on user time zone
    if ( IsStringWithData( $Param{PendingDate} ) ) {
        $Param{PendingDate} = $Self->_TransformDateSelection(
            TimeStamp    => $Param{PendingDate},
            UserTimeZone => $Param{UserTimeZone},
        );
    }

    # get dynamic field config for the screen
    $Self->{DynamicFieldFilter} = $Self->{Config}->{DynamicField};

    # get the dynamic fields for ticket object
    $Self->{DynamicField} = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => [ 'Ticket', 'Article' ],
        FieldFilter => $Self->{DynamicFieldFilter} || {},
    );

    my %DynamicFieldValues;

    # get dynamic field backend object
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # cycle trough the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
        next DYNAMICFIELD if !IsHashRefWithData( $DynamicFieldConfig->{Config} );
        next DYNAMICFIELD if !$DynamicFieldConfig->{Name};

        next DYNAMICFIELD if !$DynamicFieldBackendObject->IsIPhoneCapable(
            DynamicFieldConfig => $DynamicFieldConfig,
        );

        # extract the dynamic field value form parameters
        $DynamicFieldValues{ $DynamicFieldConfig->{Name} }
            = $DynamicFieldBackendObject->IPhoneFieldValueGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            TransformDates     => 1,
            %Param,
            );

        # perform validation of the data
        my $ValidationResult = $DynamicFieldBackendObject->IPhoneFieldValueValidate(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
            Mandatory => $Self->{Config}->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
        );

        if ( !IsHashRefWithData($ValidationResult) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Could not perform validation on field $DynamicFieldConfig->{Label}!",
            );
            return;
        }

        # propagate validation error
        if ( $ValidationResult->{ServerError} ) {

            my $ErrorMessage = $ValidationResult->{ErrorMessage}
                || "Dynamic field $DynamicFieldConfig->{Label} invalid";

            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => $ErrorMessage,
            );
            return;
        }
    }

    # send email
    my %StateData = $Kernel::OM->Get('Kernel::System::State')->StateGet( ID => $Param{StateID}, );

    # get time object
    my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

    # check pending date
    if ( $StateData{TypeName} && $StateData{TypeName} =~ /^pending/i ) {
        if ( !$TimeObject->TimeStamp2SystemTime( String => $Param{PendingDate} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Date invalid',
            );
            return;
        }
        if (
            $TimeObject->TimeStamp2SystemTime( String => $Param{PendingDate} )
            < $TimeObject->SystemTime()
            )
        {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Date invalid',
            );
            return;
        }
    }

    # get check item object
    my $CheckItemObject = $Kernel::OM->Get('Kernel::System::CheckItem');

    # check some values
    RECIPIENT:
    for my $Line (qw(From To Cc Bcc)) {
        next RECIPIENT if !$Param{$Line};
        for my $Email ( Mail::Address->parse( $Param{$Line} ) ) {
            if ( !$CheckItemObject->CheckEmail( Address => $Email->address() ) ) {
                my $ServerError = $CheckItemObject->CheckError();
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Error on field \"$Line\" \n $ServerError",
                );
                return;
            }
        }
    }

    # replace <OTRS_TICKET_STATE> with next ticket state name
    if ( $StateData{Name} ) {
        $Param{Body} =~ s/<OTRS_TICKET_STATE>/$StateData{Name}/g;
        $Param{Body} =~ s/&lt;OTRS_TICKET_STATE&gt;/$StateData{Name}/g;
    }

    # get recipients
    my $Recipients = '';
    for my $Line (qw(To Cc Bcc)) {
        if ( $Param{$Line} ) {
            if ($Recipients) {
                $Recipients .= ',';
            }
            $Recipients .= $Param{$Line};
        }
    }

    my $MimeType = 'text/plain';

    # send email
    my $ArticleID = $TicketObject->ArticleSend(
        ArticleType    => 'email-external',
        SenderType     => 'agent',
        TicketID       => $Param{TicketID},
        HistoryType    => 'SendAnswer',
        HistoryComment => "\%\%$Recipients",
        From           => $Param{From},
        To             => $Param{To},
        Cc             => $Param{Cc},
        Bcc            => $Param{Bcc},
        Subject        => $Param{Subject},
        UserID         => $Param{UserID},
        Body           => $Param{Body},
        InReplyTo      => $Param{InReplyTo},
        References     => $Param{References},
        Charset        => $ConfigObject->Get('DefaultCharset'),
        MimeType       => $MimeType,
    );

    # error page
    if ( !$ArticleID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Error no Article created! Please contact the admin',
        );
        return;
    }

    # time accounting
    if ( $Param{TimeUnits} ) {
        $TicketObject->TicketAccountTime(
            TicketID  => $Param{TicketID},
            ArticleID => $ArticleID,
            TimeUnit  => $Param{TimeUnits},
            UserID    => $Param{UserID},
        );
    }

    # set dynamic fields
    # cycle trough the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # set the object ID (TicketID or ArticleID) depending on the field configuration
        my $ObjectID
            = $DynamicFieldConfig->{ObjectType} eq 'Article' ? $ArticleID : $Param{TicketID};

        # set the value
        my $Success = $DynamicFieldBackendObject->ValueSet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ObjectID           => $ObjectID,
            Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
            UserID             => $Param{UserID},
        );
    }

    # set state
    if ( $Self->{Config}->{State} && $Param{StateID} ) {
        $TicketObject->TicketStateSet(
            TicketID => $Param{TicketID},
            StateID  => $Param{StateID},
            UserID   => $Param{UserID},
        );
    }

    # should I set an unlock?
    if ( $StateData{TypeName} =~ /^close/i ) {
        $TicketObject->TicketLockSet(
            TicketID => $Param{TicketID},
            Lock     => 'unlock',
            UserID   => $Param{UserID},
        );
    }

    # set pending time
    elsif ( $StateData{TypeName} =~ /^pending/i ) {
        $TicketObject->TicketPendingTimeSet(
            UserID   => $Param{UserID},
            TicketID => $Param{TicketID},
            String   => $Param{PendingDate},
        );
    }

    # log use response id and reply article id (useful for response diagnostics)
    my $HistoryName;
    if ( $Param{ReplyArticleID} ) {
        $HistoryName = "Response from iPhone /$Param{ReplyArticleID}/$ArticleID)";
    }
    else {
        $HistoryName = "Response from iPhone /$ArticleID)"
    }
    $TicketObject->HistoryAdd(
        Name         => $HistoryName,
        HistoryType  => 'Misc',
        TicketID     => $Param{TicketID},
        CreateUserID => $Param{UserID},
    );
    return $ArticleID;
}

sub _TicketMove {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TicketID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "No $_ is given! Please contact the admin.",
            );
            return;
        }
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    $Self->{Config} = $ConfigObject->Get('iPhone::Frontend::AgentTicketMove');

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # check permissions
    my $Access = $TicketObject->TicketPermission(
        Type     => 'move',
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID}
    );

    # error screen, don't show ticket
    if ( !$Access ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "You need $Self->{Config}->{Permission} permissions!",
        );
        return;
    }

    # get lock state
    if ( $Self->{Config}->{RequiredLock} ) {
        my $Locked = $TicketObject->TicketLockGet( TicketID => $Param{TicketID} );
        if ( !$Locked ) {
            $TicketObject->TicketLockSet(
                TicketID => $Param{TicketID},
                Lock     => 'lock',
                UserID   => $Param{UserID},
            );

            my $Success = $TicketObject->TicketOwnerSet(
                TicketID  => $Param{TicketID},
                UserID    => $Param{UserID},
                NewUserID => $Param{UserID},
            );
        }
        else {
            my $AccessOk = $TicketObject->OwnerCheck(
                TicketID => $Param{TicketID},
                OwnerID  => $Param{UserID},
            );
            if ( !$AccessOk ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Sorry, you need to be the owner to do this action! "
                        . "Please change the owner first.",
                );
                return;
            }
        }
    }

    # ticket attributes
    my %Ticket = $TicketObject->TicketGet( TicketID => $Param{TicketID} );

    # transform pending time, time stamp based on user time zone
    if ( IsStringWithData( $Param{PendingDate} ) ) {
        $Param{PendingDate} = $Self->_TransformDateSelection(
            TimeStamp    => $Param{PendingDate},
            UserTimeZone => $Param{UserTimeZone},
        );
    }

    # get dynamic field config for the screen
    $Self->{DynamicFieldFilter} = $Self->{Config}->{DynamicField};

    # get the dynamic fields for ticket object
    $Self->{DynamicField} = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => [ 'Ticket', 'Article' ],
        FieldFilter => $Self->{DynamicFieldFilter} || {},
    );

    my %DynamicFieldValues;

    # get dynamic field backend object
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # cycle trough the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
        next DYNAMICFIELD if !IsHashRefWithData( $DynamicFieldConfig->{Config} );
        next DYNAMICFIELD if !$DynamicFieldConfig->{Name};

        # skip all dynamic fields that are not designed render in iPhone App
        my $IsIPhoneCapable = $DynamicFieldBackendObject->HasBehavior(
            DynamicFieldConfig => $DynamicFieldConfig,
            Behavior           => 'IsIPhoneCapable',
        );
        next DYNAMICFIELD if !$IsIPhoneCapable;

        # extract the dynamic field value form parameters
        $DynamicFieldValues{ $DynamicFieldConfig->{Name} }
            = $DynamicFieldBackendObject->IPhoneFieldValueGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            TransformDates     => 1,
            %Param,
            );

        # perform validation of the data
        my $ValidationResult = $DynamicFieldBackendObject->IPhoneFieldValueValidate(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
            Mandatory => $Self->{Config}->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
        );

        if ( !IsHashRefWithData($ValidationResult) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Could not perform validation on field $DynamicFieldConfig->{Label}!",
            );
            return;
        }

        # propagate validation error
        if ( $ValidationResult->{ServerError} ) {

            my $ErrorMessage = $ValidationResult->{ErrorMessage}
                || "Dynamic field $DynamicFieldConfig->{Label} invalid";

            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => $ErrorMessage,
            );
            return;
        }
    }

    # DestQueueID lookup
    if ( !$Param{QueueID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No QueueID is given! Please contact the admin.",
        );
        return;
    }

    if ( $Param{OwnerID} ) {
        $Param{NewUserID} = $Param{OwnerID};
    }

    # move ticket (send notification of no new owner is selected)
    my $BodyAsText = $Param{Body} || '';
    my $Move = $TicketObject->TicketQueueSet(
        QueueID            => $Param{QueueID},
        UserID             => $Param{UserID},
        TicketID           => $Param{TicketID},
        SendNoNotification => $Param{NewUserID},
        Comment            => $BodyAsText,
    );
    if ( !$Move ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Error: ticket not moved! Please contact the admin.",
        );
        return;
    }

    # set priority
    if ( $Self->{Config}->{Priority} && $Param{PriorityID} ) {
        $TicketObject->TicketPrioritySet(
            TicketID   => $Param{TicketID},
            PriorityID => $Param{PriorityID},
            UserID     => $Param{UserID},
        );
    }

    # set state
    if ( $Self->{Config}->{State} && $Param{StateID} ) {

        $TicketObject->TicketStateSet(
            TicketID => $Param{TicketID},
            StateID  => $Param{StateID},
            UserID   => $Param{UserID},
        );

        # unlock the ticket after close
        my %StateData = $Kernel::OM->Get('Kernel::System::State')->StateGet(
            ID => $Param{StateID},
        );

        # set unlock on close state
        if ( $StateData{TypeName} =~ /^close/i ) {
            $TicketObject->TicketLockSet(
                TicketID => $Param{TicketID},
                Lock     => 'unlock',
                UserID   => $Param{UserID},
            );
        }
    }

    # check if new user is given and send notification
    if ( $Param{NewUserID} ) {

        # lock
        $TicketObject->TicketLockSet(
            TicketID => $Param{TicketID},
            Lock     => 'lock',
            UserID   => $Param{UserID},
        );

        # set owner
        $TicketObject->TicketOwnerSet(
            TicketID  => $Param{TicketID},
            UserID    => $Param{UserID},
            NewUserID => $Param{NewUserID},
            Comment   => $BodyAsText,
        );
    }

    # force unlock if no new owner is set and ticket was unlocked
    else {
        if ( $Self->{TicketUnlock} ) {
            $TicketObject->TicketLockSet(
                TicketID => $Param{TicketID},
                Lock     => 'unlock',
                UserID   => $Param{UserID},
            );
        }
    }

    # add note (send no notification)
    my $MimeType = 'text/plain';

    my %UserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
        UserID => $Param{UserID},
    );

    my $ArticleID = $TicketObject->ArticleCreate(
        TicketID       => $Param{TicketID},
        ArticleType    => 'note-internal',
        SenderType     => 'agent',
        From           => "$UserData{UserFirstname} $UserData{UserLastname} <$UserData{UserEmail}>",
        Subject        => $Param{Subject},
        Body           => $Param{Body},
        MimeType       => $MimeType,
        Charset        => $ConfigObject->Get('DefaultCharset'),
        UserID         => $Param{UserID},
        HistoryType    => 'AddNote',
        HistoryComment => '%%Move',
        NoAgentNotify  => 1,
    );

    if ( !$ArticleID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Error: Can't create an article for the moved ticket",
        );
        return;
    }

    # set dynamic fields
    # cycle trough the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # set the object ID (TicketID or ArticleID) depending on the field configuration
        my $ObjectID
            = $DynamicFieldConfig->{ObjectType} eq 'Article' ? $ArticleID : $Param{TicketID};

        # set the value
        my $Success = $DynamicFieldBackendObject->ValueSet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ObjectID           => $ObjectID,
            Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
            UserID             => $Param{UserID},
        );
    }

    # time accounting
    if ( $Param{TimeUnits} ) {
        $TicketObject->TicketAccountTime(
            TicketID  => $Param{TicketID},
            ArticleID => $ArticleID,
            TimeUnit  => $Param{TimeUnits},
            UserID    => $Param{UserID},
        );
    }

    if ($ArticleID) {
        return $ArticleID;
    }
    else {
        if ($Move) {
            return $Param{QueueID};
        }
    }
    return -1;
}

sub _TransformDateSelection {
    my ( $Self, %Param ) = @_;

    # time zone translation if needed
    if ( $Kernel::OM->Get('Kernel::Config')->Get('TimeZoneUser') && $Param{UserTimeZone} ) {

        # make sure time object has no user time zone
        $Kernel::OM->ObjectsDiscard( Objects => ['Kernel::System::Time'] );
        my $SystemTime = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
            String => $Param{TimeStamp},
        );
        $SystemTime = $SystemTime - ( $Param{UserTimeZone} * 3600 );

        # make sure time object now has the user time zone
        $Kernel::OM->ObjectsDiscard( Objects => ['Kernel::System::Time'] );
        $Kernel::OM->ObjectParamAdd(
            'Kernel::System::Time' => {
                UserTimeZone => $Param{UserTimeZone},
            },
        );

        # get time object
        my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

        $Param{TimeStamp} = $TimeObject->SystemTime2TimeStamp( SystemTime => $SystemTime );
    }
    return $Param{TimeStamp};
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
