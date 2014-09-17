# --
# Kernel/System/iPhoneHandle/ScreenConfig.pm - Screen Config base class
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::iPhoneHandle::ScreenConfig;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::CheckItem',
    'Kernel::System::CustomerUser',
    'Kernel::System::DB',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Group',
    'Kernel::Language',
    'Kernel::System::Log',
    'Kernel::System::Priority',
    'Kernel::System::Queue',
    'Kernel::System::State',
    'Kernel::System::SystemAddress',
    'Kernel::System::TemplateGenerator',
    'Kernel::System::Ticket',
    'Kernel::System::User',
);

=head1 NAME

Kernel::System::iPhoneHandle::ScreenConfig - sub module of Kernel::System::iPhoneHandle

=head1 SYNOPSIS

ScreenConfig common functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ScreenConfig()
Get fields definition for each screen (Phone, Note, Close, Compose or Move)

Phone   (New phone ticket)
Note    (Add a note to a Ticket)
Close   (Close a ticket)
Compose (Reply or response a ticket)
Move    (Change ticket queue)

Note, Close, Compose and Move, requires TicketID argument

The fields that are returned depend on the Screen Argument and on the Settings in SysConfig for the iPhone
as well as on general settings.

    my @Result = $iPhoneObject->ScreenConfig(
        Screen => "Phone",
        UserID => 1,
    );

    my @Result = $iPhoneObject->ScreenConfig(
        Screen   => "Note",
        TicketID => 224,
        UserID   => 1,
    );

    # a result could be

    @Result = (
        Actions => {
            Parameters => {
                Action => "Phone",
            },
            Method => "ScreenActions",
            Object => "CustomObject",
            Title => "New Phone Ticket"
       },
        Elements => (
            {
                Name       => "TypeID",
                Title      => "Type",
                Datatype   => "Text",
                Viewtype   => "Picker",
                Options    => {
                    1=> "default",
                    2=> "RfC",
                    3=> "Incident",
                    4=> "Incident::ServiceRequest",
                    5=> "Incident::Disaster"
                    6=> "Problem",
                    7=> "Problem::KnownError",
                    8=> "Problem::PendingRfC",
                },
                Default   =>"",
                Mandatory => 1,
            },
            {
                Name           => "CustomerUserLogin",
                Title          => "From customer",
                Datatype       => "Text",
                Viewtype       =>"AutoCompletion",
                DynamicOptions => {
                    Object     => "CustomObject",
                    Method     =>"CustomerSearch",
                    Parameters =>
                        {
                            Search => "CustomerUserLogin",
                        },
                },
                Default        => "",
                Mandatory      => 1,
            },
            {
                Name      => "QueueID",
                Title     => "To queue",
                Datatype  => "Text",
                Viewtype  => "Picker",
                Options   =>{
                      => "-",
                    1 => "Postmaster",
                    2 => "Raw",
                    3 => "Junk",
                    4 => "Misc",
                },
                Default   => "",
                Mandatory => 1,
            },
            {
                Name           => "ServiceID",
                Title          => "Service",
                Datatype       => "Text",
                Viewtype       =>"Picker",
                DynamicOptions => {
                    Object     => "CustomObject"
                    Method     => "ServicesGet",
                    Parameters => {
                        CustomerUserID => "CustomerUserLogin",
                        QueueID        => "QueueID",
                        TicketID       => "TicketID",
                    },
                },
                Mandatory      => 0,
                Default        => "",
            },
            {
                Name           => "SLAID",
                Title          => "SLA",
                Datatype       => "Text",
                Viewtype       => "Picker",
                DynamicOptions => {
                    Object     => "CustomObject",
                    Method     => "SLAsGet",
                    Parameters => {
                        CustomerUserID => "CustomerUserLogin",
                        QueueID        => "QueueID",
                        ServiceID      => "ServiceID",
                        TicketID       => "TicketID".
                    },
                },
                Default        => "",
                Mandatory      => 0,
            },
            {
                Name           => "OwnerID",
                Title          => "Owner",
                Datatype       => "Text",
                Viewtype       =>"Picker",
                DynamicOptions => {
                    Parameters => {
                        QueueID  => "QueueID",
                        AllUsers => 1,
                    },
                    Method     => "UsersGet",
                    Object     => "CustomObject",
                },
                Default        => "",
                Mandatory      => 0,
            },
            {
                Name           => "ResponsibleID",
                Title          => "Responsible",
                Datatype       => "Text",
                Viewtype       => "Picker",
                DynamicOptions => {
                    Object     => "CustomObject",
                    Method     => "UsersGet",
                    Parameters => {
                        QueueID  => "QueueID",
                        AllUsers => 1
                    },
                },
                Default        => "",
                Mandatory      => 0,
            },
            {
                Name      => "Subject",
                Title     => "Subject",
                Datatype  => "Text",
                Viewtype  => "Input",
                Max       => 250,
                Min       => 1,
                Default   => "",
                Mandatory => 1,
            },
            {
                Name      => "Body",
                Title     => "Text",
                Datatype  => "Text",
                Viewtype  => "TextArea",
                Max       => 20000,
                Min       => 1,
                Default   => "",
                Mandatory => 1,
            },
            {
                Name      => "CustomerID",
                Title     => "CustomerID",
                Datatype  => "Text",
                Viewtype  => "Input",
                Max       => 150,
                Min       => 1,
                Default   => "",
                Mandatory => 0,
            },
            {
                Name           => "StateID",
                Title          => "Next Ticket State",
                Datatype       => "Text",
                Viewtype       => "Picker",
                DynamicOptions => {
                    Method     => "NextStatesGet",
                    Object     => "CustomObject",
                    Parameters => {
                        QueueID => "QueueID",
                    },
                },
                Default        => "4",
                DefaultOption  => "open",
                Mandatory      => 1,
            },
            {
                Name      => "PendingDate",
                Title     => "Pending Date (for pending* states)"
                Datatype  => "DateTime",
                Viewtype  => "Picker",
                Default   => "",
                Mandatory => 0,
            },
            {
                Name           => "PriorityID",
                Title          => "Priority"
                Datatype       => "Text",
                Viewtype       => "Picker",
                DynamicOptions => {
                    Object     => "CustomObject"
                    Method     => "PrioritiesGet",
                    Parameters => "",
                },
                DefaultOption  => "3 normal",
                Default        => "3",
                Mandatory      => 1,
            },
            {
                Name        => "DynamicField_NameX",
                Title       => "Product",
                Datatype    => "Text",
                Viewtype    => "Picker",
                Options     => {
                             => "-",
                    Phone    => "Phone",
                    Notebook => "Notebook",
                    PC       => "PC",
                },
                Default     => "Notebook",
                Mandatory   => 0,
            },
            {
                Name => "TimeUnits",
                Title => "Time units (work units)",
                Datatype => "Numeric",
                Viewtype => "Input",
                Max => 10,
                Min => 1,
                Default => "",
                Mandatory => 0,
            },
        ),
    );

=cut

sub ScreenConfig {
    my ( $Self, %Param ) = @_;

    # define a new language object
    $Kernel::OM->ObjectsDiscard( Objects => ['Kernel::System::Language'] );
    $Kernel::OM->ObjectParamAdd(
        'Kernel::System::Language' => {
            UserLanguage => $Param{Language},
        },
    );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # ------------------------------------------------------------ #
    # New Phone Ticket Screen
    # ------------------------------------------------------------ #

    if ( $Param{Screen} eq 'Phone' ) {

        # get screen configuration options for iPhone from SysConfig
        $Self->{Config} = $ConfigObject->Get('iPhone::Frontend::AgentTicketPhone');
        my %Config = (
            Title    => $Kernel::OM->Get('Kernel::Language')->Get('New Phone Ticket'),
            Elements => $Self->_GetScreenElements(%Param),
            Actions  => {
                Object     => 'CustomObject',
                Method     => 'ScreenActions',
                Parameters => {
                    Action => 'Phone',
                },
            },
        );
        return \%Config;
    }

    # ------------------------------------------------------------ #
    # Add Note Screen
    # ------------------------------------------------------------ #
    if ( $Param{Screen} eq 'Note' ) {

        # get screen configuration options for iPhone from SysConfig
        $Self->{Config} = $ConfigObject->Get('iPhone::Frontend::AgentTicketNote');

        my %Config = (
            Title    => $Kernel::OM->Get('Kernel::Language')->Get('Add Note'),
            Elements => $Self->_GetScreenElements(%Param),
            Actions  => {
                Object     => 'CustomObject',
                Method     => 'ScreenActions',
                Parameters => {
                    Action   => 'Note',
                    TicketID => $Param{TicketID},
                    Title    => 'a title',
                },
            },
        );
        return \%Config;
    }

    # ------------------------------------------------------------ #
    # Close Ticket Screen
    # ------------------------------------------------------------ #

    if ( $Param{Screen} eq 'Close' ) {

        # get screen configuration options for iPhone from SysConfig
        $Self->{Config} = $ConfigObject->Get('iPhone::Frontend::AgentTicketClose');

        my %Config = (
            Title    => $Kernel::OM->Get('Kernel::Language')->Get('Close'),
            Elements => $Self->_GetScreenElements(%Param),
            Actions  => {
                Object     => 'CustomObject',
                Method     => 'ScreenActions',
                Parameters => {
                    Action   => 'Close',
                    TicketID => $Param{TicketID},
                },
            },
        );
        return \%Config;
    }

    # ------------------------------------------------------------ #
    # Compose Screen
    # ------------------------------------------------------------ #

    if ( $Param{Screen} eq 'Compose' ) {

        # get screen configuration options for iPhone from SysConfig
        $Self->{Config} = $ConfigObject->Get('iPhone::Frontend::AgentTicketCompose');

        my %Config = (
            Title    => $Kernel::OM->Get('Kernel::Language')->Get('Compose'),
            Elements => $Self->_GetScreenElements(%Param) || '',
            Actions  => {
                Object     => 'CustomObject',
                Method     => 'ScreenActions',
                Parameters => {
                    Action         => 'Compose',
                    TicketID       => $Param{TicketID},
                    ReplyArticleID => $Param{ArticleID},
                },
            },
        );
        if ( !$Config{Elements} ) {
            return -1;
        }
        return \%Config;
    }

    # ------------------------------------------------------------ #
    # Move Screen
    # ------------------------------------------------------------ #
    if ( $Param{Screen} eq 'Move' ) {

        # get screen configuration options for iPhone from SysConfig
        $Self->{Config} = $ConfigObject->Get('iPhone::Frontend::AgentTicketMove');

        my %Config = (
            Title    => $Kernel::OM->Get('Kernel::Language')->Get('Move'),
            Elements => $Self->_GetScreenElements(%Param),
            Actions  => {
                Object     => 'CustomObject',
                Method     => 'ScreenActions',
                Parameters => {
                    Action   => 'Move',
                    TicketID => $Param{TicketID},
                },
            },
        );
        return \%Config;
    }

    return -1;
}

sub _GetScreenElements {
    my ( $Self, %Param ) = @_;

    my @ScreenElements;

    # get needed objects
    my $LanguageObject = $Kernel::OM->Get('Kernel::Language');
    my $TicketObject   = $Kernel::OM->Get('Kernel::System::Ticket');

    if ( $Self->{Config}->{Title} ) {
        my %TicketData = $TicketObject->TicketGet(
            TicketID => $Param{TicketID},
            UserID   => $Param{UserID},
        );
        my $TitleDefault;
        if ( $TicketData{Title} ) {
            $TitleDefault = $TicketData{Title} || '';
        }

        my $TitleElements = {
            Name      => 'Title',
            Title     => $LanguageObject->Get('Title'),
            Datatype  => 'Text',
            ViewType  => 'Input',
            Min       => 1,
            Max       => 200,
            Mandatory => 1,
            Default   => $TitleDefault || '',
        };
        push @ScreenElements, $TitleElements;
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # type
    if ( $ConfigObject->Get('Ticket::Type') && $Self->{Config}->{TicketType} ) {
        my $TypeElements = {
            Name     => 'TypeID',
            Title    => $LanguageObject->Get('Type'),
            Datatype => 'Text',
            Viewtype => 'Picker',
            Options  => {
                %{
                    $Self->_GetTypes(
                        %Param,
                        UserID => $Param{UserID},
                        )
                },
            },
            Mandatory => 1,
            Default   => '',
        };
        push @ScreenElements, $TypeElements;
    }

    # from, to
    if ( $Param{Screen} eq 'Phone' ) {
        my $CustomerElements = {
            Name           => 'CustomerUserLogin',
            Title          => $LanguageObject->Get('From customer'),
            Datatype       => 'Text',
            Viewtype       => 'AutoCompletion',
            DynamicOptions => {
                Object     => 'CustomObject',
                Method     => 'CustomerSearch',
                Parameters => [
                    {
                        Search => 'CustomerUserLogin',
                    },
                ],
            },
            AutoFillElements => [
                {
                    ElementName => 'CustomerID',
                    Object      => 'CustomObject',
                    Method      => 'CustomerIDGet',
                    Parameters  => [
                        {
                            CustomerUserID => 'CustomerUserLogin',
                        },
                    ],
                },
            ],
            Mandatory => 1,
            Default   => '',
        };
        push @ScreenElements, $CustomerElements;
    }

    if ( $Param{Screen} eq 'Phone' || $Param{Screen} eq 'Move' ) {
        my $Title;
        if ( $Param{Screen} eq 'Phone' ) {
            $Title = 'To queue';
        }
        else {
            $Title = 'New Queue'
        }
        my $QueueElements = {
            Name     => 'QueueID',
            Title    => $LanguageObject->Get($Title),
            Datatype => 'Text',
            Viewtype => 'Picker',
            Options  => {
                %{
                    $Self->_GetTos(
                        %Param,
                        UserID => $Param{UserID},
                        )
                },
            },
            Mandatory => 1,
            Default   => '',
        };
        push @ScreenElements, $QueueElements;
    }

    # service
    if ( $ConfigObject->Get('Ticket::Service') && $Self->{Config}->{Service} ) {
        my $ServiceElements = {
            Name           => 'ServiceID',
            Title          => $LanguageObject->Get('Service'),
            Datatype       => 'Text',
            Viewtype       => 'Picker',
            DynamicOptions => {
                Object     => 'CustomObject',
                Method     => 'ServicesGet',
                Parameters => [
                    {
                        CustomerUserID => 'CustomerUserLogin',
                        QueueID        => 'QueueID',
                        TicketID       => 'TicketID',
                    },
                ],
            },
            Mandatory => 0,
            Default   => '',
        };
        push @ScreenElements, $ServiceElements;
    }

    # SLA
    if ( $ConfigObject->Get('Ticket::Service') && $Self->{Config}->{Service} ) {
        my $SLAElements = {
            Name           => 'SLAID',
            Title          => $LanguageObject->Get('SLA'),
            Datatype       => 'Text',
            Viewtype       => 'Picker',
            DynamicOptions => {
                Object     => 'CustomObject',
                Method     => 'SLAsGet',
                Parameters => [
                    {
                        CustomerUserID => 'CustomerUserLogin',
                        QueueID        => 'QueueID',
                        ServiceID      => 'ServiceID',
                        TicketID       => 'TicketID',
                    },
                ],
            },
            Mandatory => 0,
            Default   => '',
        };
        push @ScreenElements, $SLAElements;
    }

    # owner
    if ( $Self->{Config}->{Owner} ) {
        my $Title;
        if ( $Param{Screen} eq 'Move' ) {
            $Title = 'New Owner';
        }
        else {
            $Title = 'Owner';
        }

        my $OwnerElements = {
            Name           => 'OwnerID',
            Title          => $LanguageObject->Get($Title),
            Datatype       => 'Text',
            Viewtype       => 'Picker',
            DynamicOptions => {
                Object     => 'CustomObject',
                Method     => 'UsersGet',
                Parameters => [
                    {
                        QueueID  => 'QueueID',
                        AllUsers => 1,
                    },
                ],
            },
            Mandatory => 0,
            Default   => '',
        };
        push @ScreenElements, $OwnerElements;
    }

    # responsible
    if ( $ConfigObject->Get('Ticket::Responsible') && $Self->{Config}->{Responsible} ) {
        my $ResponsibleElements = {
            Name           => 'ResponsibleID',
            Title          => $LanguageObject->Get('Responsible'),
            Datatype       => 'Text',
            Viewtype       => 'Picker',
            DynamicOptions => {
                Object     => 'CustomObject',
                Method     => 'UsersGet',
                Parameters => [
                    {
                        QueueID  => 'QueueID',
                        AllUsers => 1,
                    },
                ],
            },
            Mandatory => 0,
            Default   => '',
        };
        push @ScreenElements, $ResponsibleElements;
    }

    if ( $Param{Screen} eq 'Compose' ) {
        my %ComposeDefaults = $Self->_GetComposeDefaults(
            %Param,
            UserID   => $Param{UserID},
            TicketID => $Param{TicketID},
        );

        if ( !%ComposeDefaults ) {
            return;
        }

        my $ComposeFromElements = {
            Name      => 'From',
            Title     => $LanguageObject->Get('From'),
            Datatype  => 'Text',
            Viewtype  => 'Input',
            Min       => 1,
            Max       => 50,
            Mandatory => 1,
            Readonly  => 1,
            Default   => $ComposeDefaults{From} || '',
        };
        push @ScreenElements, $ComposeFromElements;

        my $ComposeToElements = {
            Name      => 'To',
            Title     => $LanguageObject->Get('To'),
            Datatype  => 'Text',
            Viewtype  => 'EMail',
            Min       => 1,
            Max       => 50,
            Mandatory => 0,
            Default   => $ComposeDefaults{To} || '',
        };
        push @ScreenElements, $ComposeToElements;

        my $ComposeCcElements = {
            Name      => 'Cc',
            Title     => $LanguageObject->Get('Cc'),
            Datatype  => 'Text',
            Viewtype  => 'EMail',
            Min       => 1,
            Max       => 50,
            Mandatory => 0,
            Default   => $ComposeDefaults{Cc} || '',
        };
        push @ScreenElements, $ComposeCcElements;

        my $ComposeBccElements = {
            Name      => 'Bcc',
            Title     => $LanguageObject->Get('Bcc'),
            Datatype  => 'Text',
            Viewtype  => 'EMail',
            Min       => 1,
            Max       => 50,
            Mandatory => 0,
            Default   => $ComposeDefaults{Bcc} || '',
        };
        push @ScreenElements, $ComposeBccElements;

        my $SubjectElements = {
            Name      => 'Subject',
            Title     => $LanguageObject->Get('Subject'),
            Datatype  => 'Text',
            Viewtype  => 'Input',
            Min       => 1,
            Max       => 250,
            Mandatory => 1,
            Default   => $ComposeDefaults{Subject} || '',
        };
        push @ScreenElements, $SubjectElements;

        my $BodyElements = {
            Name      => 'Body',
            Title     => $LanguageObject->Get('Text'),
            Datatype  => 'Text',
            Viewtype  => 'TextArea',
            Min       => 1,
            Max       => 20_000,
            Mandatory => 1,
            Default   => $ComposeDefaults{Body} || '',
        };
        push @ScreenElements, $BodyElements;
    }

    # subject
    if ( $Param{Screen} ne 'Compose' ) {
        my $DefaultSubject = '';
        if ( $Self->{Config}->{Subject} ) {
            $DefaultSubject = $LanguageObject->Get( $Self->{Config}->{Subject} )
        }

        my $SubjectElements = {
            Name      => 'Subject',
            Title     => $LanguageObject->Get('Subject'),
            Datatype  => 'Text',
            Viewtype  => 'Input',
            Min       => 1,
            Max       => 250,
            Mandatory => 1,
            Default   => $DefaultSubject || '',
        };
        push @ScreenElements, $SubjectElements;
    }

    # body
    if ( $Param{Screen} ne 'Compose' ) {
        my $BodyElements = {
            Name      => 'Body',
            Title     => $LanguageObject->Get('Text'),
            Datatype  => 'Text',
            Viewtype  => 'TextArea',
            Min       => 1,
            Max       => 20_000,
            Mandatory => 1,
            Default   => $Self->{Config}->{Body} || '',
        };
        push @ScreenElements, $BodyElements;
    }

    # customer id
    if ( $Self->{Config}->{CustomerID} ) {
        my $CustomerElements = {
            Name      => 'CustomerID',
            Title     => $LanguageObject->Get('CustomerID'),
            Datatype  => 'Text',
            Viewtype  => 'Input',
            Min       => 1,
            Max       => 150,
            Mandatory => 0,
            Default   => '',
        };
        push @ScreenElements, $CustomerElements;
    }

    #note
    if ( $Self->{Config}->{Note} ) {

        my $DefaultArticleType;
        if ( $Self->{Config}->{ArticleTypeDefault} ) {
            $DefaultArticleType = $Self->{Config}->{ArticleTypeDefault};
        }

        my $DefaultArticleTypeID;
        if ($DefaultArticleType) {
            $DefaultArticleTypeID = $TicketObject->ArticleTypeLookup(
                ArticleType => $DefaultArticleType,
            );
        }
        my $NoteElements = {
            Name     => 'ArticleTypeID',
            Title    => $LanguageObject->Get('Note type'),
            Datatype => 'Text',
            Viewtype => 'Picker',
            Options  => {
                %{ $Self->_GetNoteTypes( %Param, ) }
            },
            Mandatory     => 1,
            Default       => $DefaultArticleTypeID || '',
            DefaultOption => $DefaultArticleType || '',
        };
        push @ScreenElements, $NoteElements;
    }

    # state
    if ( $Self->{Config}->{State} ) {

        my $DefaultState;
        if ( $Self->{Config}->{StateDefault} ) {
            $DefaultState = $Self->{Config}->{StateDefault}
        }

        my $DefaultStateID;
        if ($DefaultState) {

            # can't use StateLookup for 2.4 framework compatibility
            my %State = $Kernel::OM->Get('Kernel::System::State')->StateGet(
                Name => $DefaultState,
            );

            if (%State) {
                $DefaultStateID = $State{ID};
            }
        }

        my $StateElements = {
            Name           => 'StateID',
            Title          => $LanguageObject->Get('Next Ticket State'),
            Datatype       => 'Text',
            Viewtype       => 'Picker',
            DynamicOptions => {
                Object     => 'CustomObject',
                Method     => 'NextStatesGet',
                Parameters => [
                    {
                        QueueID => 'QueueID',
                    },
                ],
            },
            Mandatory     => 1,
            Default       => $DefaultStateID || '',
            DefaultOption => $DefaultState || '',
        };
        push @ScreenElements, $StateElements;
    }

    # pending date
    if ( $Param{Screen} eq 'Phone' || $Param{Screen} eq 'Compose' ) {
        my $PendingDateElements = {
            Name      => 'PendingDate',
            Title     => $LanguageObject->Get('Pending Date (for pending* states)'),
            Datatype  => 'DateTime',
            Viewtype  => 'Picker',
            Mandatory => 0,
            Default   => '',
        };
        push @ScreenElements, $PendingDateElements;
    }

    # priority
    if ( $Param{Screen} eq 'Phone' ) {

        my $DefaultPriority;
        if ( $Self->{Config}->{PriorityDefault} ) {
            $DefaultPriority = $Self->{Config}->{PriorityDefault};
        }

        my $DefaultPriorityID;
        if ($DefaultPriority) {
            $DefaultPriorityID = $Kernel::OM->Get('Kernel::System::Priority')->PriorityLookup(
                Priority => $DefaultPriority,
            );
        }

        my $PriorityElements = {
            Name           => 'PriorityID',
            Title          => $LanguageObject->Get('Priority'),
            Datatype       => 'Text',
            Viewtype       => 'Picker',
            DynamicOptions => {
                Object     => 'CustomObject',
                Method     => 'PrioritiesGet',
                Parameters => '',
            },
            Mandatory     => 1,
            Default       => $DefaultPriorityID || '',
            DefaultOption => $DefaultPriority || '',
        };
        push @ScreenElements, $PriorityElements;
    }

    # dynamic fields
    # get dynamic field config for the screen
    $Self->{DynamicFieldFilter} = $Self->{Config}->{DynamicField};

    # get the dynamic fields for ticket object
    $Self->{DynamicField} = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => [ 'Ticket', 'Article' ],
        FieldFilter => $Self->{DynamicFieldFilter} || {},
    );

    # get user preferences
    my %UserPreferences = $Kernel::OM->Get('Kernel::System::User')->GetPreferences(
        UserID => $Param{UserID},
    );

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

        # create $Value as undefined because a user default value could be ''
        my $Value = undef;

        # override the value from user preferences if is set
        if ( $UserPreferences{ 'UserDynamicField_' . $DynamicFieldConfig->{Name} } ) {
            $Value = $UserPreferences{ 'UserDynamicField_' . $DynamicFieldConfig->{Name} };
        }

        if ( $Param{TicketID} && $DynamicFieldConfig->{ObjectType} eq 'Ticket' ) {
            $Value = $DynamicFieldBackendObject->ValueGet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $Param{TicketID},
            );
        }

        my $FieldDefinition = $DynamicFieldBackendObject->IPhoneFieldParameterBuild(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $Value,
            UseDefaultValue    => 1,
            LanguageObject     => $LanguageObject,
            Mandatory => $Self->{Config}->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
        );

        # check if the FieldDefinition is defined and contain data, otherwise an undef variable in
        # this point will cause a NULL element in the ARRAY and will cause iPhone App to crash
        if ( IsHashRefWithData($FieldDefinition) ) {
            push @ScreenElements, $FieldDefinition;
        }
    }

    # time units
    if ( $Self->{Config}->{TimeUnits} ) {
        my $Mandatory;
        if ( $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime') ) {
            $Mandatory = 1;
        }
        else {
            $Mandatory = 0;
        }
        my $TimeUnitsMeasure  = $ConfigObject->Get('Ticket::Frontend::TimeUnits');
        my $TimeUnitsElements = {
            Name      => 'TimeUnits',
            Title     => $LanguageObject->Get("Time units $TimeUnitsMeasure"),
            Datatype  => 'Numeric',
            Viewtype  => 'Input',
            Min       => 1,
            Max       => 10,
            Mandatory => $Mandatory,
            Default   => '',
        };
        push @ScreenElements, $TimeUnitsElements;
    }
    return \@ScreenElements;
}

sub _GetTypes {
    my ( $Self, %Param ) = @_;

    my %Type = ();

    # get type
    %Type = $Kernel::OM->Get('Kernel::System::Ticket')->TicketTypeList(
        %Param,
        Action => $Param{Action},
        UserID => $Param{UserID},
    );
    return \%Type;
}

sub _GetTos {
    my ( $Self, %Param ) = @_;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # check own selection
    my %NewTos = ();
    if ( $ConfigObject->{'Ticket::Frontend::NewQueueOwnSelection'} ) {
        %NewTos = %{ $ConfigObject->{'Ticket::Frontend::NewQueueOwnSelection'} };
    }
    else {

        # SelectionType Queue or SystemAddress?
        my %Tos = ();
        if ( $ConfigObject->Get('Ticket::Frontend::NewQueueSelectionType') eq 'Queue' ) {
            %Tos = $Kernel::OM->Get('Kernel::System::Ticket')->MoveList(
                Type    => 'create',
                Action  => $Param{Action},
                QueueID => $Param{QueueID},
                UserID  => $Param{UserID},
            );
        }
        else {
            %Tos = $Kernel::OM->Get('Kernel::System::DB')->GetTableData(
                Table => 'system_address',
                What  => 'queue_id, id',
                Valid => 1,
                Clamp => 1,
            );
        }

        # get create permission queues
        my %UserGroups = $Kernel::OM->Get('Kernel::System::Group')->GroupMemberList(
            UserID => $Param{UserID},
            Type   => 'create',
            Result => 'HASH',
            Cached => 1,
        );

        # build selection string
        QUEUEID:
        for my $QueueID ( sort keys %Tos ) {
            my %QueueData = $Kernel::OM->Get('Kernel::System::Queue')->QueueGet( ID => $QueueID );

            # permission check, can we create new tickets in queue
            next QUEUEID if !$UserGroups{ $QueueData{GroupID} };

            my $String = $ConfigObject->Get('Ticket::Frontend::NewQueueSelectionString')
                || '<Realname> <<Email>> - Queue: <Queue>';
            $String =~ s/<Queue>/$QueueData{Name}/g;
            $String =~ s/<QueueComment>/$QueueData{Comment}/g;
            if ( $ConfigObject->Get('Ticket::Frontend::NewQueueSelectionType') ne 'Queue' )
            {
                my %SystemAddressData
                    = $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressGet(
                    ID => $Tos{$QueueID},
                    );
                $String =~ s/<Realname>/$SystemAddressData{Realname}/g;
                $String =~ s/<Email>/$SystemAddressData{Name}/g;
            }
            $NewTos{$QueueID} = $String;
        }
    }

    # add empty selection
    $NewTos{''} = '-';
    return \%NewTos;
}

sub _GetComposeDefaults {
    my ( $Self, %Param ) = @_;

    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'No TicketID given! Please contact the admin.',
        );
        return;
    }

    my %ComposeData;

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get last customer article or selected article ...
    my %Data;
    if ( $Param{ArticleID} ) {
        %Data = $TicketObject->ArticleGet( ArticleID => $Param{ArticleID} );
    }
    else {
        %Data = $TicketObject->ArticleLastCustomerArticle(
            TicketID => $Param{TicketID},
        );
    }

    # check article type and replace To with From (in case)
    if ( $Data{SenderType} !~ /customer/ ) {
        my $To   = $Data{To};
        my $From = $Data{From};

        # set OrigFrom for correct email quoting (xxxx wrote)
        $Data{OrigFrom} = $Data{From};

        # replace From/To, To/From because sender is agent
        $Data{From}    = $To;
        $Data{To}      = $Data{From};
        $Data{ReplyTo} = '';
    }
    else {

        # set OrigFrom for correct email quoting (xxxx wrote)
        $Data{OrigFrom} = $Data{From};
    }

    # build OrigFromName (to only use the realname)
    $Data{OrigFromName} = $Data{OrigFrom};
    $Data{OrigFromName} =~ s/<.*>|\(.*\)|\"|;|,//g;
    $Data{OrigFromName} =~ s/( $)|(  $)//g;

    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
    );

    # get customer data
    my %Customer;
    if ( $Ticket{CustomerUserID} ) {
        %Customer = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
            User => $Ticket{CustomerUserID}
        );
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # prepare body, subject, ReplyTo ...
    # re-wrap body if exists
    if ( $Data{Body} ) {
        $Data{Body} =~ s/\t/ /g;
        my $Quote = $ConfigObject->Get('Ticket::Frontend::Quote');
        if ($Quote) {
            $Data{Body} =~ s/\n/\n$Quote /g;
            $Data{Body} = "\n$Quote " . $Data{Body};
        }
        else {
            $Data{Body} = "\n" . $Data{Body};
            if ( $Data{Created} ) {
                $Data{Body} = "Date: $Data{Created}\n" . $Data{Body};
            }
            for (qw(Subject ReplyTo Reply-To Cc To From)) {
                if ( $Data{$_} ) {
                    $Data{Body} = "$_: $Data{$_}\n" . $Data{Body};
                }
            }
            $Data{Body} = "\n---- Message from $Data{From} ---\n\n" . $Data{Body};
            $Data{Body} .= "\n---- End Message ---\n";
        }
    }

    # check if Cc recipients should be used
    if ( $ConfigObject->Get('Ticket::Frontend::ComposeExcludeCcRecipients') ) {
        $Data{Cc} = '';
    }

    # get system address object
    my $SystemAddressObject = $Kernel::OM->Get('Kernel::System::SystemAddress');

    # add not local To addresses to Cc
    for my $Email ( Mail::Address->parse( $Data{To} ) ) {
        my $IsLocal = $SystemAddressObject->SystemAddressIsLocalAddress(
            Address => $Email->address(),
        );
        if ( !$IsLocal ) {
            if ( $Data{Cc} ) {
                $Data{Cc} .= ', ';
            }
            $Data{Cc} .= $Email->format();
        }
    }

    # check ReplyTo
    if ( $Data{ReplyTo} ) {
        $Data{To} = $Data{ReplyTo};
    }
    else {
        $Data{To} = $Data{From};

        # try to remove some wrong text to from line (by way of ...)
        # added by some strange mail programs on bounce
        $Data{To} =~ s/(.+?\<.+?\@.+?\>)\s+\(by\s+way\s+of\s+.+?\)/$1/ig;
    }

    # get to email (just "some@example.com")
    for my $Email ( Mail::Address->parse( $Data{To} ) ) {
        $Data{ToEmail} = $Email->address();
    }

    # use customer database email
    if ( $ConfigObject->Get('Ticket::Frontend::ComposeAddCustomerAddress') ) {

        # check if customer is in recipient list
        if ( $Customer{UserEmail} && $Data{ToEmail} !~ /^\Q$Customer{UserEmail}\E$/i ) {

            # replace To with customers database address
            if ( $ConfigObject->Get('Ticket::Frontend::ComposeReplaceSenderAddress') ) {
                $Data{To} = $Customer{UserEmail};
            }

            # add customers database address to Cc
            else {
                if ( $Data{Cc} ) {
                    $Data{Cc} .= ', ' . $Customer{UserEmail};
                }
                else {
                    $Data{Cc} = $Customer{UserEmail};
                }
            }
        }
    }

    # find duplicate addresses
    my %Recipient;
    for my $Type (qw(To Cc Bcc)) {
        if ( $Data{$Type} ) {
            my $NewLine = '';
            for my $Email ( Mail::Address->parse( $Data{$Type} ) ) {
                my $Address = lc $Email->address();

                # only use email addresses with @ inside
                if ( $Address && $Address =~ /@/ && !$Recipient{$Address} ) {
                    $Recipient{$Address} = 1;
                    my $IsLocal = $SystemAddressObject->SystemAddressIsLocalAddress(
                        Address => $Address,
                    );
                    if ( !$IsLocal ) {
                        if ($NewLine) {
                            $NewLine .= ', ';
                        }
                        $NewLine .= $Email->format();
                    }
                }
            }
            $Data{$Type} = $NewLine;
        }
    }

    $Param{ResponseID} = 1;

    # set no RichText in order to get text/plain template for the iPhone
    $ConfigObject->Set( Key => 'Frontend::RichText', Value => 0 );

    # get template
    my $TemplateGeneratorObject = $Kernel::OM->Get('Kernel::System::TemplateGenerator');

    $Data{Salutation} = $TemplateGeneratorObject->Salutation(
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
        Data     => \%Data,
    );
    $Data{Signature} = $TemplateGeneratorObject->Signature(
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
        Data     => \%Data,
    );

    %Data = $TemplateGeneratorObject->Attributes(
        TicketID   => $Param{TicketID},
        ArticleID  => $Param{ArticleID},
        ResponseID => $Param{ResponseID},
        Data       => \%Data,
        UserID     => $Param{UserID},
    );

    my $Salutation = $Data{Salutation};
    my $OrigFrom   = $Data{OrigFrom};
    my $Wrote      = $Kernel::OM->Get('Kernel::Language')->Get('wrote');
    my $Body       = $Data{Body};
    my $Signature  = $Data{Signature};

    my $ResponseFormat
        = "$Salutation \n $OrigFrom $Wrote: \n $Body \n $Signature \n";

    # restore qdata formatting for Output replacement
    $ResponseFormat =~ s/&quot;/"/gi;

    # prepare subject
    my $Tn = $TicketObject->TicketNumberLookup( TicketID => $Param{TicketID} );
    $Param{Subject} = $TicketObject->TicketSubjectBuild(
        TicketNumber => $Tn,
        Subject => $Param{Subject} || '',
    );

    # get check item object
    my $CheckItemObject = $Kernel::OM->Get('Kernel::System::CheckItem');

    # check some values
    RECIPIENT:
    for my $Line (qw(To Cc Bcc)) {
        next RECIPIENT if !$Data{$Line};
        for my $Email ( Mail::Address->parse( $Data{$Line} ) ) {
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
    if ( $Data{From} ) {
        for my $Email ( Mail::Address->parse( $Data{From} ) ) {
            if ( !$CheckItemObject->CheckEmail( Address => $Email->address() ) ) {
                my $ServerError = $CheckItemObject->CheckError();
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Error on field \"From\"  \n $ServerError",
                );
                return;
            }
        }
    }

    %ComposeData = (
        From    => $Data{From},
        To      => $Data{To},
        Cc      => $Data{Cc},
        Bcc     => $Data{Bcc},
        ReplyTo => $Data{ReplyTo},
        Subject => $Data{Subject},
        Body    => $ResponseFormat,
    );
    return %ComposeData;
}

sub _GetNoteTypes {
    my ( $Self, %Param ) = @_;

    my %DefaultNoteTypes = %{ $Self->{Config}->{ArticleTypes} };

    my %NoteTypes = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleTypeList( Result => 'HASH' );
    for ( sort keys %NoteTypes ) {
        if ( !$DefaultNoteTypes{ $NoteTypes{$_} } ) {
            delete $NoteTypes{$_};
        }
    }
    return \%NoteTypes;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
