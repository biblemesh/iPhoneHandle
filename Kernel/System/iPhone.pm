# --
# Kernel/System/iPhone.pm - all iPhone handle functions
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::iPhone;

use strict;
use warnings;

use Kernel::Language;
use Kernel::System::Time;
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::CheckItem',
    'Kernel::System::CustomerUser',
    'Kernel::System::DB',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Group',
    'Kernel::System::Lock',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Priority',
    'Kernel::System::Queue',
    'Kernel::System::State',
    'Kernel::System::SystemAddress',
    'Kernel::System::TemplateGenerator',
    'Kernel::System::Ticket',
    'Kernel::System::Time',
    'Kernel::System::User',
);

=head1 NAME

Kernel::System::iPhone - iPhone lib

=head1 SYNOPSIS

All iPhone functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ValidObject = $Kernel::OM->Get('Kernel::System::iPhone');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

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

    my $LanguageObject = Kernel::Language->new( UserLanguage => $Param{Language} );
    $Param{LanguageObject} = $LanguageObject;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # ------------------------------------------------------------ #
    # New Phone Ticket Screen
    # ------------------------------------------------------------ #

    if ( $Param{Screen} eq 'Phone' ) {

        # get screen configuration options for iPhone from SysConfig
        $Self->{Config} = $ConfigObject->Get('iPhone::Frontend::AgentTicketPhone');
        my %Config = (
            Title    => $LanguageObject->Get('New Phone Ticket'),
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
            Title    => $LanguageObject->Get('Add Note'),
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
            Title    => $LanguageObject->Get('Close'),
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
            Title    => $LanguageObject->Get('Compose'),
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
            Title    => $LanguageObject->Get('Move'),
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

=item Badges()

Get Badges ticket counts for Watched, Locked and Responsible for tickets

    my @Result = $iPhoneObject->Badges(
        UserID          => 1,
    );

    # a result could be

    @Result = (
        Locked => {
            All => 1,
            New => 1,
        },

        Watched => {       # Optional if feature is enabled
            All => 2,
            New => 0,
        },

        Responsible => {   # Optional if feature is enabled
            All => 1,
            New => 1,
        },
    );

=cut

sub Badges {
    my ( $Self, %Param ) = @_;

    my @Data;

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # locked
    if (1) {
        my $Count = $TicketObject->TicketSearch(
            Result     => 'COUNT',
            Locks      => ['lock'],
            OwnerIDs   => [ $Param{UserID} ],
            UserID     => 1,
            Permission => 'ro',
        );
        my $CountNew = $TicketObject->TicketSearch(
            Result     => 'COUNT',
            Locks      => ['lock'],
            OwnerIDs   => [ $Param{UserID} ],
            TicketFlag => {
                Seen => 1,
            },
            TicketFlagUserID => $Param{UserID},
            UserID           => 1,
            Permission       => 'ro',
        );
        $CountNew = $Count - $CountNew;
        push @Data, {
            Locked => {
                All => $Count,
                New => $CountNew,
                }
        };
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # responsible
    if ( $ConfigObject->Get('Ticket::Responsible') ) {
        my $Count = $TicketObject->TicketSearch(
            Result         => 'COUNT',
            StateType      => 'Open',
            ResponsibleIDs => [ $Param{UserID} ],
            UserID         => 1,
            Permission     => 'ro',
        );
        my $CountNew = $TicketObject->TicketSearch(
            Result         => 'COUNT',
            StateType      => 'Open',
            ResponsibleIDs => [ $Param{UserID} ],
            TicketFlag     => {
                Seen => 1,
            },
            TicketFlagUserID => $Param{UserID},
            UserID           => 1,
            Permission       => 'ro',
        );
        $CountNew = $Count - $CountNew;

        push @Data, {
            Responsible => {
                All => $Count,
                New => $CountNew,
                }
        };
    }

    # watched
    if ( $ConfigObject->Get('Ticket::Watcher') ) {

        # check access
        my $AccessOk = 1;
        my @Groups;
        if ( $ConfigObject->Get('Ticket::WatcherGroup') ) {
            @Groups = @{ $ConfigObject->Get('Ticket::WatcherGroup') };
        }
        if (@Groups) {
            my $Access = 0;
            GROUP:
            for my $Group (@Groups) {
                next GROUP if !$Param{"UserIsGroup[$Group]"};
                if ( $Param{"UserIsGroup[$Group]"} eq 'Yes' ) {
                    $Access = 1;
                    last GROUP;
                }
            }

            # return on no access
            if ( !$Access ) {
                $AccessOk = 0;
            }
        }

        if ($AccessOk) {

            # find watched tickets
            my $Count = $TicketObject->TicketSearch(
                Result       => 'COUNT',
                WatchUserIDs => [ $Param{UserID} ],
                UserID       => 1,
                Permission   => 'ro',
            );
            my $CountNew = $TicketObject->TicketSearch(
                Result       => 'COUNT',
                WatchUserIDs => [ $Param{UserID} ],
                TicketFlag   => {
                    Seen => 1,
                },
                TicketFlagUserID => $Param{UserID},
                UserID           => 1,
                Permission       => 'ro',
            );
            $CountNew = $Count - $CountNew;

            push @Data, {
                Watched => {
                    All => $Count,
                    New => $CountNew,
                    }
            };
        }
    }

    return @Data;
}

=item EscalationView()

Get the number of tickets on escalation status by state type or last customer article information from
each ticket in escalation status within a filter, if the "Filter" argument is specified.

    my @Result = $iPhoneObject->EscalationView(
        UserID  => 1,

        # OrderBy and SortBy (optional)
        OrderBy => 'Down',  # Down|Up
        SortBy  => 'Age',   # Owner|Responsible|CustomerID|State|TicketNumber|Queue|Priority|Age
                            # Type|Lock|Title|Service|SLA|PendingTime|EscalationTime
                            # EscalationUpdateTime|EscalationResponseTime|EscalationSolutionTime
    );

    # a result could be

    @Result = (
        {
            StateType                      => "Today",
            NumberOfTickets                => 2,
            NumberOfTicketsWithNewMessages => 0,
        },
        {
            StateType                      => "Tomorrow",
            NumberOfTickets                => 2,
            NumberOfTicketsWithNewMessages => 0,
        },
        {
            StateType                      => "NextWeek",
            NumberOfTickets                => 2,
            NumberOfTicketsWithNewMessages => 0
        },
    );

    my @Result = $iPhoneObject->EscalationView(
        UserID  => 1,
        Filter  => "Today",

        #Limit (optional) set to 100 by default, if not specified
        Limit   => 50,

        # OrderBy and SortBy (optional)
        OrderBy => 'Down',  # Down|Up
        SortBy  => 'Age',   # Owner|Responsible|CustomerID|State|TicketNumber|Queue|Priority|Age
                            # Type|Lock|Title|Service|SLA|PendingTime|EscalationTime
                            # EscalationUpdateTime|EscalationResponseTime|EscalationSolutionTime
    );

    #a result could be

    @Result = (
        {
            Age                              => 1596,
            ArticleID                        => 923,
            ArticleType                      => "phone",
            Body                             => "Testing for escalation",
            Charset                          => "utf-8",
            ContentCharset                   => "utf-8",
            ContentType                      => "text/plain;",
            charset                          => "utf-8",
            Created                          => "2010-06-23 11:46:15",
            CreatedBy                        => 1,
            FirstResponseTime                => -1296,
            FirstResponseTimeDestinationDate => "2010-06-23 11:51:14",
            FirstResponseTimeDestinationTime => 1277311874,
            FirstResponseTimeEscalation      => 1,
            FirstResponseTimeWorkingTime     => -1260,
            From                             => "customer@otrs.org",
            IncomingTime                     => 1277311575,
            Lock                             => "unlock",
            MimeType                         => "text/plain",
            Owner                            => "Agent1",
            Priority                         => "3 normal",
            PriorityColor                    => "#cdcdcd",
            Queue                            => "Junk",
            Responsible                      => "Agent1",
            SenderType                       => "customer",
            SolutionTime                     => -1296,
            SolutionTimeDestinationDate      => "2010-06-23 11:51:14",
            SolutionTimeDestinationTime      => 1277311874,
            SolutionTimeEscalation           => 1,
            SolutionTimeWorkingTime          => -1260,
            State                            => "open",
            Subject                          => "Escalation Test",
            TicketID                         => 176,
            TicketNumber                     => 2010062310000015,
            Title                            => "Escalation Test",
            To                               => "Junk",
            Type                             => "Incident",
            UntilTime                        => 0,
            UpdateTime                       => -1295,
            UpdateTimeDestinationDate        => "2010-06-23 11:51:15",
            UpdateTimeDestinationTime        => 1277311875,
            UpdateTimeEscalation             => 1,
            UpdateTimeWorkingTime            => -1260,
            Seen                             => 1,
        },
    );

=cut

sub EscalationView {
    my ( $Self, %Param ) = @_;

    # get time object
    my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

    my ( $Sec, $Min, $Hour, $Day, $Month, $Year ) = $TimeObject->SystemTime2Date(
        SystemTime => $TimeObject->SystemTime() + 60 * 60 * 24 * 7,
    );
    my $TimeStampNextWeek = "$Year-$Month-$Day 23:59:59";

    ( $Sec, $Min, $Hour, $Day, $Month, $Year ) = $TimeObject->SystemTime2Date(
        SystemTime => $TimeObject->SystemTime() + 60 * 60 * 24,
    );
    my $TimeStampTomorrow = "$Year-$Month-$Day 23:59:59";

    ( $Sec, $Min, $Hour, $Day, $Month, $Year ) = $TimeObject->SystemTime2Date(
        SystemTime => $TimeObject->SystemTime(),
    );
    my $TimeStampToday = "$Year-$Month-$Day 23:59:59";

    # define filter
    my %Filters = (
        Today => {
            Name   => 'Today',
            Prio   => 1000,
            Search => {
                TicketEscalationTimeOlderDate => $TimeStampToday,
                OrderBy                       => $Param{OrderBy},
                SortBy                        => $Param{SortBy},
                UserID                        => $Param{UserID},
                Permission                    => 'ro',
            },
        },
        Tomorrow => {
            Name   => 'Tomorrow',
            Prio   => 2000,
            Search => {
                TicketEscalationTimeOlderDate => $TimeStampTomorrow,
                OrderBy                       => $Param{OrderBy},
                SortBy                        => $Param{SortBy},
                UserID                        => $Param{UserID},
                Permission                    => 'ro',
            },
        },
        NextWeek => {
            Name   => 'Next Week',
            Prio   => 3000,
            Search => {
                TicketEscalationTimeOlderDate => $TimeStampNextWeek,
                OrderBy                       => $Param{OrderBy},
                SortBy                        => $Param{SortBy},
                UserID                        => $Param{UserID},
                Permission                    => 'ro',
            },
        },
    );

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # do shown tickets lookup
    my $Limit = $Param{Limit} || 100;
    if ( $Param{Filter} ) {
        my @ViewableTickets = $TicketObject->TicketSearch(
            %{ $Filters{ $Param{Filter} }->{Search} },
            Limit  => $Limit,
            Result => 'ARRAY',
        );
        my @List;
        TICKETID:
        for my $TicketID (@ViewableTickets) {
            next TICKETID if !$TicketID;
            my %Article = $Self->TicketList( TicketID => $TicketID, UserID => $Param{UserID} );
            next TICKETID if !%Article;
            push @List, \%Article;
        }
        return @List;
    }

    # do NavBar lookup
    my @States;
    for my $Filter ( sort keys %Filters ) {
        my $Count = $TicketObject->TicketSearch(
            %{ $Filters{$Filter}->{Search} },
            Result => 'COUNT',
        );
        my $CountNew = $TicketObject->TicketSearch(
            %{ $Filters{$Filter}->{Search} },
            Result     => 'COUNT',
            TicketFlag => {
                Seen => 1,
            },
            TicketFlagUserID => $Param{UserID},
        );
        $CountNew = $Count - $CountNew;

        push @States, {
            StateType                      => $Filter,
            FilterName                     => $Filters{$Filter}->{Name},
            NumberOfTickets                => $Count,
            NumberOfTicketsWithNewMessages => $CountNew,
        };
    }
    return @States;
}

=item StatusView()

Get the number of tickets by status (open or closed) or last customer article information from each
ticket in each status within an specified filter, if the "Filter" argument is specified.

    my @Result = $iPhoneObject->StatusView(
        UserID  => 1,

        # OrderBy and SortBy (optional)
        OrderBy => 'Down',  # Down|Up
        SortBy  => 'Age',   # Owner|Responsible|CustomerID|State|TicketNumber|Queue|Priority|Age
                            # Type|Lock|Title|Service|SLA|PendingTime|EscalationTime
                            # EscalationUpdateTime|EscalationResponseTime|EscalationSolutionTime
    );

    #a result could be

    @Result = (
        {
            StateType                      => "Open",
            NumberOfTickets                => 2,
            NumberOfTicketsWithNewMessages => 0,
        },
        {
            StateType                      => "Closed",
            NumberOfTickets                => 1,
            NumberOfTicketsWithNewMessages => 0,
        },
    );

    my @Result = $iPhoneObject->StatusView(
        UserID  => 1,
        Filter  => "Open",

        #Limit (optional) set to 100 by default, if not specified
        Limit   => 50,

        # OrderBy and SortBy (optional)
        OrderBy => 'Down',  # Down|Up
        SortBy  => 'Age',   # Owner|Responsible|CustomerID|State|TicketNumber|Queue|Priority|Age
                            # Type|Lock|Title|Service|SLA|PendingTime|EscalationTime
                            # EscalationUpdateTime|EscalationResponseTime|EscalationSolutionTime
    );

    #a result could be

    @Result = (
        {
             Age                              => 1596,
            ArticleID                        => 923,
            ArticleType                      => "phone",
            Body                             => "This is an open ticket",
            Charset                          => "utf-8",
            ContentCharset                   => "utf-8",
            ContentType                      => "text/plain;",
            charset                          => "utf-8",
            Created                          => "2010-06-23 11:46:15",
            CreatedBy                        => 1,
            FirstResponseTime                => -1296,
            FirstResponseTimeDestinationDate => "2010-06-23 11:51:14",
            FirstResponseTimeDestinationTime => 1277311874,
            FirstResponseTimeEscalation      => 1,
            FirstResponseTimeWorkingTime     => -1260,
            From                             => "customer@otrs.org",
            IncomingTime                     => 1277311575,
            Lock                             => "unlock",
            MimeType                         => "text/plain",
            Owner                            => "Agent1",
            Priority                         => "3 normal",
            PriorityColor                    => "#cdcdcd",
            Queue                            => "Junk",
            Responsible                      => "Agent1",
            SenderType                       => "customer",
            SolutionTime                     => -1296,
            SolutionTimeDestinationDate      => "2010-06-23 11:51:14",
            SolutionTimeDestinationTime      => 1277311874,
            SolutionTimeEscalation           => 1,
            SolutionTimeWorkingTime          => -1260,
            State                            => "open",
            Subject                          => "Open Ticket Test",
            TicketID                         => 176,
            TicketNumber                     => 2010062310000015,
            Title                            => "Open Ticket Test",
            To                               => "Junk",
            Type                             => "Incident",
            UntilTime                        => 0,
            UpdateTime                       => -1295,
            UpdateTimeDestinationDate        => "2010-06-23 11:51:15",
            UpdateTimeDestinationTime        => 1277311875,
            UpdateTimeEscalation             => 1,
            UpdateTimeWorkingTime            => -1260,
            Seen                             => 1,
        },
    );

=cut

sub StatusView {
    my ( $Self, %Param ) = @_;

    # define filter
    my %Filters = (
        Open => {
            Name   => 'Open',
            Prio   => 1000,
            Search => {
                StateType  => 'Open',
                OrderBy    => $Param{OrderBy},
                SortBy     => $Param{SortBy},
                UserID     => $Param{UserID},
                Permission => 'ro',
            },
        },
        Closed => {
            Name   => 'Closed',
            Prio   => 1001,
            Search => {
                StateType  => 'Closed',
                OrderBy    => $Param{OrderBy},
                SortBy     => $Param{SortBy},
                UserID     => $Param{UserID},
                Permission => 'ro',
            },
        },
    );

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # do shown tickets lookup
    my $Limit = $Param{Limit} || 100;
    if ( $Param{Filter} ) {
        my @ViewableTickets = $TicketObject->TicketSearch(
            %{ $Filters{ $Param{Filter} }->{Search} },
            Limit  => $Limit,
            Result => 'ARRAY',
        );
        my @List;
        for my $TicketID (@ViewableTickets) {
            TICKETID:
            next TICKETID if !$TicketID;
            my %Article = $Self->TicketList( TicketID => $TicketID, UserID => $Param{UserID} );
            next TICKETID if !%Article;
            push @List, \%Article;
        }
        return @List;
    }

    # do NavBar lookup
    my @States;
    for my $Filter ( sort keys %Filters ) {
        my $Count = $TicketObject->TicketSearch(
            %{ $Filters{$Filter}->{Search} },
            Result => 'COUNT',
        );
        my $CountNew = $TicketObject->TicketSearch(
            %{ $Filters{$Filter}->{Search} },
            Result     => 'COUNT',
            TicketFlag => {
                Seen => 1,
            },
            TicketFlagUserID => $Param{UserID},
        );
        $CountNew = $Count - $CountNew;

        push @States, {
            StateType                      => $Filter,
            FilterName                     => $Filters{$Filter}->{Name},
            NumberOfTickets                => $Count,
            NumberOfTicketsWithNewMessages => $CountNew,
        };
    }
    return @States;
}

=item LockedView()

Get the number of locked tickets by status type (all, new, reminder, reminder reached ) or last
customer article information from each locked ticket in each status within an specified filter, if
the "Filter" argument is specified.

    my @Result = $iPhoneObject->LockedView(
        UserID  => 1,

        # OrderBy and SortBy (optional)
        OrderBy => 'Down',  # Down|Up
        SortBy  => 'Age',   # Owner|Responsible|CustomerID|State|TicketNumber|Queue|Priority|Age
                            # Type|Lock|Title|Service|SLA|PendingTime|EscalationTime
                            # EscalationUpdateTime|EscalationResponseTime|EscalationSolutionTime
    );

    #a result could be

    @Result = (
        {
            StateType                      => "All",
            NumberOfTickets                => 2,
            NumberOfTicketsWithNewMessages => 0,
        },
        {
            StateType                      => "New,
            NumberOfTickets                => 1,
            NumberOfTicketsWithNewMessages => 0,
        },
        {
            StateType                      => "Reminder,
            NumberOfTickets                => 0,
            NumberOfTicketsWithNewMessages => 0,
        },
        {
            StateType                      => "ReminderReached,
            NumberOfTickets                => 1,
            NumberOfTicketsWithNewMessages => 0,
        },
    );

    my @Result = $iPhoneObject->LockedView(
        UserID  => 1,
        Filter  => "New",

        #Limit (optional) set to 100 by default, if not specified
        Limit   => 50,

        # OrderBy and SortBy (optional)
        OrderBy => 'Down',  # Down|Up
        SortBy  => 'Age',   # Owner|Responsible|CustomerID|State|TicketNumber|Queue|Priority|Age
                            # Type|Lock|Title|Service|SLA|PendingTime|EscalationTime
                            # EscalationUpdateTime|EscalationResponseTime|EscalationSolutionTime
    );

    #a result could be

    @Result = (
        {
            Age                              => 1596,
            ArticleID                        => 923,
            ArticleType                      => "phone",
            Body                             => "This is an open ticket",
            Charset                          => "utf-8",
            ContentCharset                   => "utf-8",
            ContentType                      => "text/plain;",
            charset                          => "utf-8",
            Created                          => "2010-06-23 11:46:15",
            CreatedBy                        => 1,
            FirstResponseTime                => -1296,
            FirstResponseTimeDestinationDate => "2010-06-23 11:51:14",
            FirstResponseTimeDestinationTime => 1277311874,
            FirstResponseTimeEscalation      => 1,
            FirstResponseTimeWorkingTime     => -1260,
            From                             => "customer@otrs.org",
            IncomingTime                     => 1277311575,
            Lock                             => "lock",
            MimeType                         => "text/plain",
            Owner                            => "Agent1",
            Priority                         => "3 normal",
            PriorityColor                    => "#cdcdcd",
            Queue                            => "Junk",
            Responsible                      => "Agent1",
            SenderType                       => "customer",
            SolutionTime                     => -1296,
            SolutionTimeDestinationDate      => "2010-06-23 11:51:14",
            SolutionTimeDestinationTime      => 1277311874,
            SolutionTimeEscalation           => 1,
            SolutionTimeWorkingTime          => -1260,
            State                            => "open",
            Subject                          => "Open Ticket Test",
            TicketID                         => 176,
            TicketNumber                     => 2010062310000015,
            Title                            => "Open Ticket Test",
            To                               => "Junk",
            Type                             => "Incident",
            UntilTime                        => 0,
            UpdateTime                       => -1295,
            UpdateTimeDestinationDate        => "2010-06-23 11:51:15",
            UpdateTimeDestinationTime        => 1277311875,
            UpdateTimeEscalation             => 1,
            UpdateTimeWorkingTime            => -1260,
            Seen                             => 1, # only on otrs 3.x framework
        },
    );

=cut

sub LockedView {
    my ( $Self, %Param ) = @_;

    # define filter
    my %Filters = (
        All => {
            Name   => 'All',
            Prio   => 1000,
            Search => {
                Locks      => ['lock'],
                OwnerIDs   => [ $Param{UserID} ],
                OrderBy    => $Param{OrderBy},
                SortBy     => $Param{SortBy},
                UserID     => 1,
                Permission => 'ro',
            },
        },
        New => {
            Name   => 'New Article',
            Prio   => 1001,
            Search => {
                Locks      => ['lock'],
                OwnerIDs   => [ $Param{UserID} ],
                TicketFlag => {
                    Seen => 1,
                },
                TicketFlagUserID => $Param{UserID},
                OrderBy          => $Param{OrderBy},
                SortBy           => $Param{SortBy},
                UserID           => 1,
                Permission       => 'ro',
            },
        },
        Reminder => {
            Name   => 'Pending',
            Prio   => 1002,
            Search => {
                Locks      => ['lock'],
                StateType  => [ 'pending reminder', 'pending auto' ],
                OwnerIDs   => [ $Param{UserID} ],
                OrderBy    => $Param{OrderBy},
                SortBy     => $Param{SortBy},
                UserID     => 1,
                Permission => 'ro',
            },
        },
        ReminderReached => {
            Name   => 'Reminder Reached',
            Prio   => 1003,
            Search => {
                Locks                         => ['lock'],
                StateType                     => ['pending reminder'],
                TicketPendingTimeOlderMinutes => 1,
                OwnerIDs                      => [ $Param{UserID} ],
                OrderBy                       => $Param{OrderBy},
                SortBy                        => $Param{SortBy},
                UserID                        => 1,
                Permission                    => 'ro',
            },
        },
    );

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # do shown tickets lookup
    my $Limit = $Param{Limit} || 100;
    if ( $Param{Filter} ) {
        my @ViewableTickets = $TicketObject->TicketSearch(
            %{ $Filters{ $Param{Filter} }->{Search} },
            Limit  => $Limit,
            Result => 'ARRAY',
        );
        my @List;
        for my $TicketID (@ViewableTickets) {
            TICKETID:
            next TICKETID if !$TicketID;
            my %Article = $Self->TicketList( TicketID => $TicketID, UserID => $Param{UserID} );
            next TICKETID if !%Article;
            push @List, \%Article;
        }

        if ( !@List ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "There are no locked tickets under $Param{Filter} filter "
                    . "category",
            );
        }

        return @List;
    }

    # do NavBar lookup
    my @States;
    for my $Filter ( sort keys %Filters ) {
        my $Count = $TicketObject->TicketSearch(
            %{ $Filters{$Filter}->{Search} },
            Result => 'COUNT',
        );
        my $CountNew = $TicketObject->TicketSearch(
            %{ $Filters{$Filter}->{Search} },
            Result     => 'COUNT',
            TicketFlag => {
                Seen => 1,
            },
            TicketFlagUserID => $Param{UserID},
        );
        $CountNew = $Count - $CountNew;

        push @States, {
            StateType                      => $Filter,
            FilterName                     => $Filters{$Filter}->{Name},
            NumberOfTickets                => $Count,
            NumberOfTicketsWithNewMessages => $CountNew,
        };
    }
    return @States;
}

=item WatchedView()

Get the number of watched tickets by status type (all, new, reminder, reminder reached ) or last
customer article information from each watched ticket in each status within an specified filter, if
the "Filter" argument is specified.

    my @Result = $iPhoneObject->WatchedView(
        UserID  => 1,

        # OrderBy and SortBy (optional)
        OrderBy => 'Down',  # Down|Up
        SortBy  => 'Age',   # Owner|Responsible|CustomerID|State|TicketNumber|Queue|Priority|Age
                            # Type|Lock|Title|Service|SLA|PendingTime|EscalationTime
                            # EscalationUpdateTime|EscalationResponseTime|EscalationSolutionTime
    );

    #a result could be

    @Result = (
        {
            StateType                      => "All",
            NumberOfTickets                => 2,
            NumberOfTicketsWithNewMessages => 0,
        },
        {
            StateType                      => "New,
            NumberOfTickets                => 1,
            NumberOfTicketsWithNewMessages => 0,
        },
        {
            StateType                      => "Reminder,
            NumberOfTickets                => 0,
            NumberOfTicketsWithNewMessages => 0,
        },
        {
            StateType                      => "ReminderReached,
            NumberOfTickets                => 1,
            NumberOfTicketsWithNewMessages => 0,
        },
    );

    my @Result = $iPhoneObject->WatchedView(
        UserID  => 1,
        Filter  => "New",

        #Limit (optional) set to 100 by default, if not specified
        Limit   => 50,

        # OrderBy and SortBy (optional)
        OrderBy => 'Down',  # Down|Up
        SortBy  => 'Age',   # Owner|Responsible|CustomerID|State|TicketNumber|Queue|Priority|Age
                            # Type|Lock|Title|Service|SLA|PendingTime|EscalationTime
                            # EscalationUpdateTime|EscalationResponseTime|EscalationSolutionTime
    );

    #a result could be

    @Result = (
        {
            Age                              => 1596,
            ArticleID                        => 923,
            ArticleType                      => "phone",
            Body                             => "This is an open ticket",
            Charset                          => "utf-8",
            ContentCharset                   => "utf-8",
            ContentType                      => "text/plain;",
            charset                          => "utf-8",
            Created                          => "2010-06-23 11:46:15",
            CreatedBy                        => 1,
            FirstResponseTime                => -1296,
            FirstResponseTimeDestinationDate => "2010-06-23 11:51:14",
            FirstResponseTimeDestinationTime => 1277311874,
            FirstResponseTimeEscalation      => 1,
            FirstResponseTimeWorkingTime     => -1260,
            From                             => "customer@otrs.org",
            IncomingTime                     => 1277311575,
            Lock                             => "lock",
            MimeType                         => "text/plain",
            Owner                            => "Agent1",
            Priority                         => "3 normal",
            PriorityColor                    => "#cdcdcd",
            Queue                            => "Junk",
            Responsible                      => "Agent1",
            SenderType                       => "customer",
            SolutionTime                     => -1296,
            SolutionTimeDestinationDate      => "2010-06-23 11:51:14",
            SolutionTimeDestinationTime      => 1277311874,
            SolutionTimeEscalation           => 1,
            SolutionTimeWorkingTime          => -1260,
            State                            => "open",
            Subject                          => "Open Ticket Test",
            TicketID                         => 176,
            TicketNumber                     => 2010062310000015,
            Title                            => "Open Ticket Test",
            To                               => "Junk",
            Type                             => "Incident",
            UntilTime                        => 0,
            UpdateTime                       => -1295,
            UpdateTimeDestinationDate        => "2010-06-23 11:51:15",
            UpdateTimeDestinationTime        => 1277311875,
            UpdateTimeEscalation             => 1,
            UpdateTimeWorkingTime            => -1260,
            Seen                             => 1, # only on otrs 3.x framework
        },
    );

=cut

sub WatchedView {
    my ( $Self, %Param ) = @_;

    # define filter
    # get all watched tickets no matter if they are locked or not
    my %Filters = (
        All => {
            Name   => 'All',
            Prio   => 1000,
            Search => {
                WatchUserIDs => [ $Param{UserID} ],
                OrderBy      => $Param{OrderBy},
                SortBy       => $Param{SortBy},
                UserID       => 1,
                Permission   => 'ro',
            },
        },
        New => {
            Name   => 'New Article',
            Prio   => 1001,
            Search => {
                WatchUserIDs => [ $Param{UserID} ],
                TicketFlag   => {
                    Seen => 1,
                },
                TicketFlagUserID => $Param{UserID},
                OrderBy          => $Param{OrderBy},
                SortBy           => $Param{SortBy},
                UserID           => 1,
                Permission       => 'ro',
            },
        },
        Reminder => {
            Name   => 'Pending',
            Prio   => 1002,
            Search => {
                StateType => [ 'pending reminder', 'pending auto' ],
                WatchUserIDs => [ $Param{UserID} ],
                OrderBy      => $Param{OrderBy},
                SortBy       => $Param{SortBy},
                UserID       => 1,
                Permission   => 'ro',
            },
        },
        ReminderReached => {
            Name   => 'Reminder Reached',
            Prio   => 1003,
            Search => {
                StateType                     => ['pending reminder'],
                TicketPendingTimeOlderMinutes => 1,
                WatchUserIDs                  => [ $Param{UserID} ],
                OrderBy                       => $Param{OrderBy},
                SortBy                        => $Param{SortBy},
                UserID                        => 1,
                Permission                    => 'ro',
            },
        },
    );

    if ( $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Watcher') ) {

        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        # do shown tickets lookup
        my $Limit = $Param{Limit} || 100;
        if ( $Param{Filter} ) {
            my @ViewableTickets = $TicketObject->TicketSearch(
                %{ $Filters{ $Param{Filter} }->{Search} },
                Limit  => $Limit,
                Result => 'ARRAY',
            );
            my @List;
            for my $TicketID (@ViewableTickets) {
                TICKETID:
                next TICKETID if !$TicketID;
                my %Article = $Self->TicketList( TicketID => $TicketID, UserID => $Param{UserID} );
                next TICKETID if !%Article;
                push @List, \%Article;
            }
            if ( !@List ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "There are no watched tickets under $Param{Filter} filter "
                        . "category",
                );
            }
            return @List;
        }

        # do NavBar lookup
        my @States;
        for my $Filter ( sort keys %Filters ) {
            my $Count = $TicketObject->TicketSearch(
                %{ $Filters{$Filter}->{Search} },
                Result => 'COUNT',
            );
            my $CountNew = $TicketObject->TicketSearch(
                %{ $Filters{$Filter}->{Search} },
                Result     => 'COUNT',
                TicketFlag => {
                    Seen => 1,
                },
                TicketFlagUserID => $Param{UserID},
            );
            $CountNew = $Count - $CountNew;

            push @States, {
                StateType                      => $Filter,
                FilterName                     => $Filters{$Filter}->{Name},
                NumberOfTickets                => $Count,
                NumberOfTicketsWithNewMessages => $CountNew,
            };
        }
        return @States;
    }
    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'error',
        Message  => 'Ticket watcher feature is not enable in system configuration '
            . 'Please contact admin',
    );
    return -1;
}

=item ResponsibleView()

Get the number of locked or unlocked tickets where the user is responsible for by status type
(all, new, reminder, reminder reached ) or last customer article information from each ticket where
the user is responsible for  in each status within an specified filter, if the "Filter" argument is
specified.

    my @Result = $iPhoneObject->ResponsibleView(
        UserID  => 1,

        # OrderBy and SortBy (optional)
        OrderBy => 'Down',  # Down|Up
        SortBy  => 'Age',   # Owner|Responsible|CustomerID|State|TicketNumber|Queue|Priority|Age
                            # Type|Lock|Title|Service|SLA|PendingTime|EscalationTime
                            # EscalationUpdateTime|EscalationResponseTime|EscalationSolutionTime
    );

    #a result could be

    @Result = (
        {
            StateType                      => "All",
            NumberOfTickets                => 2,
            NumberOfTicketsWithNewMessages => 0,
        },
        {
            StateType                      => "New,
            NumberOfTickets                => 1,
            NumberOfTicketsWithNewMessages => 0,
        },
        {
            StateType                      => "Reminder,
            NumberOfTickets                => 0,
            NumberOfTicketsWithNewMessages => 0,
        },
        {
            StateType                      => "ReminderReached,
            NumberOfTickets                => 1,
            NumberOfTicketsWithNewMessages => 0,
        },
    );

    my @Result = $iPhoneObject->ResponsibleView(
        UserID  => 1,
        Filter  => "New",

        #Limit (optional) set to 100 by default, if not specified
        Limit   => 50,

        # OrderBy and SortBy (optional)
        OrderBy => 'Down',  # Down|Up
        SortBy  => 'Age',   # Owner|Responsible|CustomerID|State|TicketNumber|Queue|Priority|Age
                            # Type|Lock|Title|Service|SLA|PendingTime|EscalationTime
                            # EscalationUpdateTime|EscalationResponseTime|EscalationSolutionTime
    );

    #a result could be

    @Result = (
        {
            Age                              => 1596,
            ArticleID                        => 923,
            ArticleType                      => "phone",
            Body                             => "This is an open ticket",
            Charset                          => "utf-8",
            ContentCharset                   => "utf-8",
            ContentType                      => "text/plain;",
            charset                          => "utf-8",
            Created                          => "2010-06-23 11:46:15",
            CreatedBy                        => 1,
            FirstResponseTime                => -1296,
            FirstResponseTimeDestinationDate => "2010-06-23 11:51:14",
            FirstResponseTimeDestinationTime => 1277311874,
            FirstResponseTimeEscalation      => 1,
            FirstResponseTimeWorkingTime     => -1260,
            From                             => "customer@otrs.org",
            IncomingTime                     => 1277311575,
            Lock                             => "lock",
            MimeType                         => "text/plain",
            Owner                            => "Agent1",
            Priority                         => "3 normal",
            PriorityColor                    => "#cdcdcd",
            Queue                            => "Junk",
            Responsible                      => "Agent1",
            SenderType                       => "customer",
            SolutionTime                     => -1296,
            SolutionTimeDestinationDate      => "2010-06-23 11:51:14",
            SolutionTimeDestinationTime      => 1277311874,
            SolutionTimeEscalation           => 1,
            SolutionTimeWorkingTime          => -1260,
            State                            => "open",
            Subject                          => "Open Ticket Test",
            TicketID                         => 176,
            TicketNumber                     => 2010062310000015,
            Title                            => "Open Ticket Test",
            To                               => "Junk",
            Type                             => "Incident",
            UntilTime                        => 0,
            UpdateTime                       => -1295,
            UpdateTimeDestinationDate        => "2010-06-23 11:51:15",
            UpdateTimeDestinationTime        => 1277311875,
            UpdateTimeEscalation             => 1,
            UpdateTimeWorkingTime            => -1260,
            Seen                             => 1, # only on otrs 3.x framework
        },
    );

=cut

sub ResponsibleView {
    my ( $Self, %Param ) = @_;

    # define filter
    my %Filters = (
        All => {
            Name   => 'All',
            Prio   => 1000,
            Search => {
                StateType      => 'Open',
                ResponsibleIDs => [ $Param{UserID} ],
                OrderBy        => $Param{OrderBy},
                SortBy         => $Param{SortBy},
                UserID         => 1,
                Permission     => 'ro',
            },
        },
        New => {
            Name   => 'New Article',
            Prio   => 1001,
            Search => {
                StateType      => 'Open',
                ResponsibleIDs => [ $Param{UserID} ],
                TicketFlag     => {
                    Seen => 1,
                },
                TicketFlagUserID => $Param{UserID},
                OrderBy          => $Param{OrderBy},
                SortBy           => $Param{SortBy},
                UserID           => 1,
                Permission       => 'ro',
            },
        },
        Reminder => {
            Name   => 'Pending',
            Prio   => 1002,
            Search => {
                StateType => [ 'pending reminder', 'pending auto' ],
                ResponsibleIDs => [ $Param{UserID} ],
                OrderBy        => $Param{OrderBy},
                SortBy         => $Param{SortBy},
                UserID         => 1,
                Permission     => 'ro',
            },
        },
        ReminderReached => {
            Name   => 'Reminder Reached',
            Prio   => 1003,
            Search => {
                StateType                     => ['pending reminder'],
                TicketPendingTimeOlderMinutes => 1,
                ResponsibleIDs                => [ $Param{UserID} ],
                OrderBy                       => $Param{OrderBy},
                SortBy                        => $Param{SortBy},
                UserID                        => 1,
                Permission                    => 'ro',
            },
        },
    );

    if ( $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Responsible') ) {

        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        # do shown tickets lookup
        my $Limit = $Param{Limit} || 100;
        if ( $Param{Filter} ) {
            my @ViewableTickets = $TicketObject->TicketSearch(
                %{ $Filters{ $Param{Filter} }->{Search} },
                Limit  => $Limit,
                Result => 'ARRAY',
            );
            my @List;
            TICKETID:
            for my $TicketID (@ViewableTickets) {
                next TICKETID if !$TicketID;
                my %Article = $Self->TicketList( TicketID => $TicketID, UserID => $Param{UserID} );
                next TICKETID if !%Article;
                push @List, \%Article;
            }
            if ( !@List ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "There are no responsible for tickets under $Param{Filter} filter "
                        . "category",
                );
            }
            return @List;
        }

        # do NavBar lookup
        my @States;
        for my $Filter ( sort keys %Filters ) {
            my $Count = $TicketObject->TicketSearch(
                %{ $Filters{$Filter}->{Search} },
                Result => 'COUNT',
            );
            my $CountNew = $TicketObject->TicketSearch(
                %{ $Filters{$Filter}->{Search} },
                Result     => 'COUNT',
                TicketFlag => {
                    Seen => 1,
                },
                TicketFlagUserID => $Param{UserID},
            );
            $CountNew = $Count - $CountNew;

            push @States, {
                StateType                      => $Filter,
                FilterName                     => $Filters{$Filter}->{Name},
                NumberOfTickets                => $Count,
                NumberOfTicketsWithNewMessages => $CountNew,
            };
        }
        return @States;
    }
    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'error',
        Message  => 'Ticket responsible feature is not enable in system configuration '
            . 'Please contact admin',
    );
    return -1;
}

=item QueueView()

Get the number of viewable tickets per queue as well as basic queue information, or last customer
article information from each ticket within an specified queue, if the "Queue" argument is
specified.

    my @Result = $iPhoneObject->QueueView(
        UserID  => 1,

        # OrderBy and SortBy (optional)
        OrderBy => 'Down',  # Down|Up
        SortBy  => 'Age',   # Owner|Responsible|CustomerID|State|TicketNumber|Queue|Priority|Age
                            # Type|Lock|Title|Service|SLA|PendingTime|EscalationTime
                            # EscalationUpdateTime|EscalationResponseTime|EscalationSolutionTime
    );

    #a result could be

    @Result = (
        {
            QueueName                      => "Junk",
            NumberOfTickets                => 2,
            NumberOfTicketsWithNewMessages => 0,
            QueueID                        => 3,
            Comment                        => "All junk tickets."
        },
        {
            QueueName                      => "Misc",
            NumberOfTickets                => 1,
            NumberOfTicketsWithNewMessages => 0,
            QueueID                        => 4,
            Comment                        => "All misc tickets."
        },
    );

    my @Result = $iPhoneObject->QueueView(
        UserID   => 1,
        QueueID  => 4,

        #Limit (optional) set to 100 by default, if not specified
        Limit    => 50,

        # OrderBy and SortBy (optional)
        OrderBy  => 'Down',  # Down|Up
        SortBy   => 'Age',   # Owner|Responsible|CustomerID|State|TicketNumber|Queue|Priority|Age
                            # Type|Lock|Title|Service|SLA|PendingTime|EscalationTime
                            # EscalationUpdateTime|EscalationResponseTime|EscalationSolutionTime
    );

    #a result could be

    @Result = (
        {
            Age                              => 1596,
            ArticleID                        => 923,
            ArticleType                      => "phone",
            Body                             => "This is an open ticket",
            Charset                          => "utf-8",
            ContentCharset                   => "utf-8",
            ContentType                      => "text/plain;",
            charset                          => "utf-8",
            Created                          => "2010-06-23 11:46:15",
            CreatedBy                        => 1,
            FirstResponseTime                => -1296,
            FirstResponseTimeDestinationDate => "2010-06-23 11:51:14",
            FirstResponseTimeDestinationTime => 1277311874,
            FirstResponseTimeEscalation      => 1,
            FirstResponseTimeWorkingTime     => -1260,
            From                             => "customer@otrs.org",
            IncomingTime                     => 1277311575,
            Lock                             => "lock",
            MimeType                         => "text/plain",
            Owner                            => "Agent1",
            Priority                         => "3 normal",
            PriorityColor                    => "#cdcdcd",
            Queue                            => "Misc",
            Responsible                      => "Agent1",
            SenderType                       => "customer",
            SolutionTime                     => -1296,
            SolutionTimeDestinationDate      => "2010-06-23 11:51:14",
            SolutionTimeDestinationTime      => 1277311874,
            SolutionTimeEscalation           => 1,
            SolutionTimeWorkingTime          => -1260,
            State                            => "open",
            Subject                          => "Open Ticket Test",
            TicketID                         => 176,
            TicketNumber                     => 2010062310000015,
            Title                            => "Open Ticket Test",
            To                               => "Junk",
            Type                             => "Incident",
            UntilTime                        => 0,
            UpdateTime                       => -1295,
            UpdateTimeDestinationDate        => "2010-06-23 11:51:15",
            UpdateTimeDestinationTime        => 1277311875,
            UpdateTimeEscalation             => 1,
            UpdateTimeWorkingTime            => -1260,
            Seen                             => 1, # only on otrs 3.x framework
        },
    );

=cut

sub QueueView {
    my ( $Self, %Param ) = @_;

    my @ViewableLockIDs
        = $Kernel::OM->Get('Kernel::System::Lock')->LockViewableLock( Type => 'ID' );

    my @ViewableStateIDs = $Kernel::OM->Get('Kernel::System::State')->StateGetStatesByType(
        Type   => 'Viewable',
        Result => 'ID',
    );

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # do shown tickets lookup
    my $Limit = $Param{Limit} || 100;
    if ( $Param{QueueID} ) {
        my @ViewableTickets = $TicketObject->TicketSearch(

            OrderBy    => $Param{OrderBy},
            SortBy     => $Param{SortBy},
            StateIDs   => \@ViewableStateIDs,
            LockIDs    => \@ViewableLockIDs,
            QueueIDs   => [ $Param{QueueID} ],
            Permission => 'rw',
            UserID     => $Param{UserID},
            Limit      => $Limit,
            Result     => 'ARRAY',
        );
        my @List;
        TICKETID:
        for my $TicketID (@ViewableTickets) {
            next TICKETID if !$TicketID;
            my %Article = $Self->TicketList( TicketID => $TicketID, UserID => $Param{UserID} );
            next TICKETID if !%Article;
            push @List, \%Article;
        }
        return @List;
    }

    # get queue object
    my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');

    my %AllQueues = $QueueObject->QueueList( Valid => 0 );

    my @Queues;
    my %QueueSum;
    QUEUEID:
    for my $QueueID ( sort keys %AllQueues ) {
        my %Queue = $QueueObject->QueueGet(
            ID => $QueueID,
        );

        my $Count = $TicketObject->TicketSearch(
            StateIDs => \@ViewableStateIDs,
            LockIDs  => \@ViewableLockIDs,
            QueueIDs => [$QueueID],

            Permission => 'rw',
            UserID     => $Param{UserID},
            Result     => 'COUNT',
            Limit      => 1000,
        );
        next QUEUEID if !$Count;

        my $CountNew = $TicketObject->TicketSearch(
            StateIDs => \@ViewableStateIDs,
            LockIDs  => \@ViewableLockIDs,
            QueueIDs => [$QueueID],

            TicketFlag => {
                Seen => 1,
            },
            TicketFlagUserID => $Param{UserID},
            Permission       => 'rw',
            UserID           => $Param{UserID},
            Result           => 'COUNT',
            Limit            => 1000,
        );
        $CountNew = $Count - $CountNew;

        push @Queues, {
            QueueID   => $QueueID,
            QueueName => $Queue{Name},
            Comment   => $Queue{Comment},

            NumberOfTickets                => $Count,
            NumberOfTicketsWithNewMessages => $CountNew,
        };
    }

    return @Queues;
}

=item TicketList()

Get the last customer article information of a ticket

    my @Result = $iPhoneObject->TicketList(
        UserID   => 1,
        TicketID  => 176,
    );

    #a result could be

    @Result = (
        {
            Age                              => 1596,
            ArticleID                        => 923,
            ArticleType                      => "phone",
            Body                             => "This is an open ticket",
            Charset                          => "utf-8",
            ContentCharset                   => "utf-8",
            ContentType                      => "text/plain;",
            charset                          => "utf-8",
            Created                          => "2010-06-23 11:46:15",
            CreatedBy                        => 1,
            FirstResponseTime                => -1296,
            FirstResponseTimeDestinationDate => "2010-06-23 11:51:14",
            FirstResponseTimeDestinationTime => 1277311874,
            FirstResponseTimeEscalation      => 1,
            FirstResponseTimeWorkingTime     => -1260,
            From                             => "customer@otrs.org",
            IncomingTime                     => 1277311575,
            Lock                             => "lock",
            MimeType                         => "text/plain",
            Owner                            => "Agent1",
            Priority                         => "3 normal",
            PriorityColor                    => "#cdcdcd",
            Queue                            => "Misc",
            Responsible                      => "Agent1",
            SenderType                       => "customer",
            SolutionTime                     => -1296,
            SolutionTimeDestinationDate      => "2010-06-23 11:51:14",
            SolutionTimeDestinationTime      => 1277311874,
            SolutionTimeEscalation           => 1,
            SolutionTimeWorkingTime          => -1260,
            State                            => "open",
            Subject                          => "Open Ticket Test",
            TicketID                         => 176,
            TicketNumber                     => 2010062310000015,
            Title                            => "Open Ticket Test",
            To                               => "Junk",
            Type                             => "Incident",
            UntilTime                        => 0,
            UpdateTime                       => -1295,
            UpdateTimeDestinationDate        => "2010-06-23 11:51:15",
            UpdateTimeDestinationTime        => 1277311875,
            UpdateTimeEscalation             => 1,
            UpdateTimeWorkingTime            => -1260,
            Seen                             => 1, # only on otrs 3.x framework
        },
    );

=cut

sub TicketList {
    my ( $Self, %Param ) = @_;

    my %Color = (
        1 => '#cdcdcd',
        2 => '#cdcdcd',
        3 => '#cdcdcd',
        4 => '#ffaaaa',
        5 => '#ff505e',
    );

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %Article = $TicketObject->ArticleLastCustomerArticle(
        TicketID => $Param{TicketID},
    );
    if (%Article) {
        $Article{PriorityColor} = $Color{ $Article{PriorityID} };

        my %TicketFlag = $TicketObject->TicketFlagGet(
            TicketID => $Param{TicketID},
            UserID   => $Param{UserID},
        );
        if ( $TicketFlag{seen} || $TicketFlag{Seen} ) {
            $Article{Seen} = 1;
        }

        # strip out all data
        my @Delete = qw(
            ReplyTo MessageID InReplyTo References AgeTimeUnix CreateTimeUnix SenderTypeID
            IncomingTime RealTillTimeNotUsed ServiceID SLAID StateType ArchiveFlag UnlockTimeout
            Changed
            )
            ;

        for my $Key (@Delete) {
            delete $Article{$Key};
        }

        for my $Key ( sort keys %Article ) {
            if ( !defined $Article{$Key} || $Article{$Key} eq '' ) {
                delete $Article{$Key};
            }
            if ( $Key =~ /^Escala/ ) {
                delete $Article{$Key};
            }
        }

        return %Article;
    }

    # return only ticket information if ticket has no articles
    my %TicketData = $Self->TicketGet(
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID}
    );
    return %TicketData;
}

=item TicketGet()
Get information of a ticket

    my @Result = $iPhoneObject->TicketGet(
        TicketID  => 224,
        UserID    => 1,
    );

    #a result could be

    @Result = (
        AccountedTime   => "5404",
        Age             => "681946",
        CustomerID      => "sw",
        CustomerUserID  => "David",
        Created         => "2010-07-06 14:05:54",
        GroupID         => 1,
        TicketID        => 224,
        LockID          => 2,
        Lock            => "lock"
        OwnerID         => 1134,
        Owner           => "Aayla",
        PriorityColor   => "#cdcdcd",
        PriorityID      => 1,
        Priority        => "1 very low",
        Queue           => "Raw",
        QueueID         => 2,
        ResponsibleID   => 1134,
        Responsible     => "Aayla",
        Seen            => 1, # only on otrs 3.x framework
        StateID         =>  4,
        State           => "open",
        TicketNumber    => "2010070610000215",
        Title           => "iPhone Test",
        TypeID          => 1,
        Type            => "default",
        UntilTime       => "0",
    );

=cut

sub TicketGet {
    my ( $Self, %Param ) = @_;

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # permission check
    my $Access = $TicketObject->TicketPermission(
        Type     => 'ro',
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID}
    );
    if ( !$Access ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "You need ro permissions!",
        );
        return;
    }

    my %Color = (
        1 => '#cdcdcd',
        2 => '#cdcdcd',
        3 => '#cdcdcd',
        4 => '#ffaaaa',
        5 => '#ff505e',
    );

    my %Ticket = $TicketObject->TicketGet(%Param);

    $Ticket{PriorityColor} = $Color{ $Ticket{PriorityID} };

    my %TicketFlag = $TicketObject->TicketFlagGet(
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
    );
    if ( $TicketFlag{seen} || $TicketFlag{Seen} ) {
        $Ticket{Seen} = 1;
    }
    else {

        # check if ticket need to be marked as seen
        my $ArticleAllSeen = 1;
        my @Index = $TicketObject->ArticleIndex( TicketID => $Ticket{TicketID} );
        if ( IsArrayRefWithData( \@Index ) ) {
            ARTICLEID:
            for my $ArticleID (@Index) {
                my %ArticleFlag = $TicketObject->ArticleFlagGet(
                    ArticleID => $ArticleID,
                    UserID    => $Param{UserID},
                );

                # last if article was not shown
                if ( !$ArticleFlag{Seen} && !$ArticleFlag{seen} ) {
                    $ArticleAllSeen = 0;
                    last ARTICLEID;
                }
            }

            # mark ticket as seen if all article are shown
            if ($ArticleAllSeen) {
                $TicketObject->TicketFlagSet(
                    TicketID => $Ticket{TicketID},
                    Key      => 'Seen',
                    Value    => 1,
                    UserID   => $Param{UserID},
                );
            }
        }
    }

    # add accounted time
    my $AccountedTime = $TicketObject->TicketAccountedTimeGet(%Param);
    if ( defined $AccountedTime ) {
        $Ticket{AccountedTime} = $AccountedTime;
    }

    # strip out all data
    my @Delete = qw(
        ReplyTo MessageID InReplyTo References AgeTimeUnix CreateTimeUnix SenderTypeID
        IncomingTime RealTillTimeNotUsed ServiceID SLAID StateType ArchiveFlag UnlockTimeout
        Changed
        )
        ;

    for my $Key (@Delete) {
        delete $Ticket{$Key};
    }
    for my $Key ( sort keys %Ticket ) {
        if ( !defined $Ticket{$Key} || $Ticket{$Key} eq '' ) {
            delete $Ticket{$Key};
        }
        if ( $Key =~ /^Escala/ ) {
            delete $Ticket{$Key};
        }
    }
    return %Ticket;
}

=item ArticleGet()

Get information from an article

    my %Result = $iPhoneObject->ArticleGet()
        ArticleID  => 1054,
        UserID     => 1,
    );

    #a result could be

    %Resutl = (
        Age                              => 166202,
        AccountedTime                    => 123,
        ArticleID                        => 1054,
        ArticleTypeID                    => 5,
        ArticleType                      => "phone",
        Body                             => "iPhone ticket Test",
        Charset                          => "utf-8",
        ContentCharset                   => "utf-8",
        ContentType                      => "text/plain; charset=utf-8",
        Created                          => "2010-07-12 14:13:06",
        CreatedBy                        => 1134,
        CustomerID                       => "sw",
        CustomerUserID                   => "David",
        FirstResponseTimeDestinationDate => "2010-07-12 14:18:06",
        FirstResponseTimeDestinationTime => "1278962286",
        FirstResponseTimeEscalation      => 1,
        FirstResponseTimeWorkingTime     => -86700,
        FirstResponseTime                => -165902,
        From                             => "\"David Prowse\" <pd@sw.com>",
        LockID                           => 2,
        Lock                             => "lock",
        MimeType                         => "text/plain",
        OwnerID                          => 1134,
        Owner                            => "Aayla",
        PriorityID                       => 1,
        Priority                         => "1 very low",
        QueueID                          => 3,
        Queue                            => "Junk",
        ResponsibleID                    => 1134,
        Responsible                      => "Aayla",
        Seen                             => 1, # only on otrs 3.x framework
        SenderType                       => "customer",
        SolutionTimeDestinationDate      => "2010-07-12 14:18:06",
        SolutionTimeDestinationTime      => 1278962286,
        SolutionTimeWorkingTime          => -86700,
        SolutionTimeEscalation           => 1,
        SolutionTime                     => -165902,
        StateID                          => 4,
        Subject                          => "iPhone Test",
        State                            => "open",
        TicketID                         => 247,
        TicketNumber                     => "2010071210000043",
        Title                            => "iPhone Test",
        To                               => "Junk",
        TypeID                           => 1,
        Type                             => "default",
        UpdateTimeDestinationDate        => "2010-07-12 14:18:06",
        UpdateTimeDestinationTime        => 1278962286,
        UpdateTimeEscalation             => 1,
        UpdateTimeWorkingTime            => -86700,
        UpdateTime                       => -165902,
        UntilTime                        => 0,
    );

=cut

sub ArticleGet {
    my ( $Self, %Param ) = @_;

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # permission check
    my %Article = $TicketObject->ArticleGet(%Param);
    my $Access  = $TicketObject->TicketPermission(
        Type     => 'ro',
        TicketID => $Article{TicketID},
        UserID   => $Param{UserID}
    );
    if ( !$Access ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "You need ro permissions!",
        );
        return;
    }

    if (%Article) {

        # check if article is seen
        my %ArticleFlag = $TicketObject->ArticleFlagGet(
            ArticleID => $Param{ArticleID},
            UserID    => $Param{UserID},
        );
        if ( $ArticleFlag{seen} || $ArticleFlag{Seen} ) {
            $Article{Seen} = 1;
        }

        # mark shown article as seen
        $TicketObject->ArticleFlagSet(
            ArticleID => $Param{ArticleID},
            Key       => 'Seen',
            Value     => 1,
            UserID    => $Param{UserID},
        );

        # check if ticket need to be marked as seen
        my $ArticleAllSeen = 1;
        my @Index = $TicketObject->ArticleIndex( TicketID => $Article{TicketID} );
        if ( IsArrayRefWithData( \@Index ) ) {
            ARTICEID:
            for my $ArticleID (@Index) {
                my %ArticleFlag = $TicketObject->ArticleFlagGet(
                    ArticleID => $ArticleID,
                    UserID    => $Param{UserID},
                );

                # last if article was not shown
                if ( !$ArticleFlag{Seen} && !$ArticleFlag{seen} ) {
                    $ArticleAllSeen = 0;
                    last ARTICLEID;
                }
            }

            # mark ticket as seen if all article are shown
            if ($ArticleAllSeen) {
                $TicketObject->TicketFlagSet(
                    TicketID => $Article{TicketID},
                    Key      => 'Seen',
                    Value    => 1,
                    UserID   => $Param{UserID},
                );
            }
        }

        # add accounted time
        my $AccountedTime = $TicketObject->ArticleAccountedTimeGet(%Param);
        if ( defined $AccountedTime ) {
            $Article{AccountedTime} = $AccountedTime;
        }

        # strip out all data
        my @Delete = qw(
            ReplyTo MessageID InReplyTo References AgeTimeUnix CreateTimeUnix SenderTypeID
            IncomingTime RealTillTimeNotUsed ServiceID SLAIDStateType ArchiveFlag UnlockTimeout
            Changed
            )
            ;

        for my $Key (@Delete) {
            delete $Article{$Key};
        }

        for my $Key ( sort keys %Article ) {
            if ( !defined $Article{$Key} || $Article{$Key} eq '' ) {
                delete $Article{$Key};
            }
            if ( $Key =~ /^Escala/ ) {
                delete $Article{$Key};
            }
        }

        return %Article;
    }
    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'error',
        Message  => 'No Articles found in this ticket',
    );
    return -1;
}

=item ServicesGet()
Get a Hash reference to all possible services based on a Ticket or Queue and CustomerUser

    my $Result = $iPhoneObject->ServicesGet(
        UserID          => 1,
        QueueID         => 3,  # || TicketID Optional
        TicketID        => 23, # || QueueID Optional
        CustomerUserID  => "Customer",
    );

    # a result could be

    $Result = [
        1 => "Service A",
        3 => "Service A::SubService 1",
        2 => "Service B"
    ],

=cut

sub ServicesGet {
    my ( $Self, %Param ) = @_;

    my %Service = ();

    # get service
    if ( ( $Param{QueueID} || $Param{TicketID} ) && $Param{CustomerUserID} ) {
        %Service = $Kernel::OM->Get('Kernel::System::Ticket')->TicketServiceList(
            %Param,
            Action => $Param{Action},
            UserID => $Param{UserID},
        );
    }
    return \%Service;
}

=item SLAsGet()
Get a Hash reference to all possible SLAs based on a Service

    my $Result = $iPhoneObject->SLAsGet(
        ServiceID       => 1,
        QueueID         => 3,  #|| TickeTID optional
        TicketID        => 223 #|| QueueID optional
        UserID          => 1,
    );

    # a result could be

    $Result = [
        1 => "SLA Gold for Service A",
        3 => "SLA Silver for Service A",
    ],

=cut

sub SLAsGet {
    my ( $Self, %Param ) = @_;

    my %SLA = ();

    # get SLA
    if ( $Param{ServiceID} ) {
        %SLA = $$Kernel::OM->Get('Kernel::System::Ticket')->TicketSLAList(
            %Param,
            Action => $Param{Action},
            UserID => $Param{UserID},
        );
    }
    return \%SLA;
}

=item UsersGet()
Get a Hash reference to all users that have rights on a Queue or the users that have that queue in
the "My Queues" list

    my $Result = $iPhoneObject->UsersGet(
        QueueID         => 3,
        AllUsers        => 1 # Optional, To get the complete list of users with rights in the queue
        UserID          => 1,
    );

    # a result could be

    $Result = [
        1    => "OTRS Admin (root@localhost)",
        1138 => "Amy Allen (Aayla) "
    ],

=cut

sub UsersGet {
    my ( $Self, %Param ) = @_;

    # get users
    my %ShownUsers       = ();
    my %AllGroupsMembers = $Kernel::OM->Get('Kernel::System::User')->UserList(
        Type  => 'Long',
        Valid => 1,
    );

    # just show only users with selected custom queue
    if ( $Param{QueueID} && !$Param{AllUsers} ) {
        my @UserIDs
            = $Kernel::OM->Get('Kernel::System::Ticket')->GetSubscribedUserIDsByQueueID(%Param);
        for ( sort keys %AllGroupsMembers ) {
            my $Hit = 0;
            for my $UID (@UserIDs) {
                if ( $UID eq $_ ) {
                    $Hit = 1;
                }
            }
            if ( !$Hit ) {
                delete $AllGroupsMembers{$_};
            }
        }
    }

    # show all system users
    if ( $Kernel::OM->Get('Kernel::Config')->Get('Ticket::ChangeOwnerToEveryone') ) {
        %ShownUsers = %AllGroupsMembers;
    }

    # show all users who are rw in the queue group
    elsif ( $Param{QueueID} ) {
        my $GID = $Kernel::OM->Get('Kernel::System::Queue')->GetQueueGroupID(
            QueueID => $Param{QueueID},
        );
        my %MemberList = $Kernel::OM->Get('Kernel::System::Group')->GroupMemberList(
            GroupID => $GID,
            Type    => 'rw',
            Result  => 'HASH',
            Cached  => 1,
        );
        for ( sort keys %MemberList ) {
            if ( $AllGroupsMembers{$_} ) {
                $ShownUsers{$_} = $AllGroupsMembers{$_};
            }
        }
    }
    return \%ShownUsers;
}

=item NextStatesGet()
Get a Hash reference to all possible states based on a Ticket or Queue

    my $Result = $iPhoneObject->NextStatesGet(
        QueueID         => 3,  #|| TickeTID optional
        TicketID        => 223 #|| QueueID optional
        UserID          => 1,
    );

    # a result could be

    $Result = [
        1  => "new",
        2  => "closed successful",
        3  => "closed unsuccessful",
        4  => "open",
        5  => "removed"
        6  => "pending reminder",
        7  => "pending auto close+",
        8  => "pending auto close-",
        9  => "merged",
        10 => "closed with workaround",
    ],

=cut

sub NextStatesGet {
    my ( $Self, %Param ) = @_;

    my %NextStates = ();
    if ( $Param{QueueID} || $Param{TicketID} ) {
        %NextStates = $Kernel::OM->Get('Kernel::System::Ticket')->StateList(
            %Param,
            Action => $Param{Action},
            UserID => $Param{UserID},
        );
    }
    return \%NextStates;
}

=item PrioritiesGet()
Get a Hash reference to all possible priorities

    my $Result = $iPhoneObject->PrioritiesGet(
        UserID          => 1,
    );

    # a result could be

    $Result = [
        1 => "1 very low",
        2 => "2 low",
        3 => "3 normal",
        4 => "4 high",
        5 => "5 very high",
    ],

=cut

sub PrioritiesGet {
    my ( $Self, %Param ) = @_;

    my %Priorities = ();

    # get priority
    %Priorities = $Kernel::OM->Get('Kernel::System::Ticket')->PriorityList(
        %Param,
        Action => $Param{Action},
        UserID => $Param{UserID},
    );

    return \%Priorities;
}

=item CustomerSearch()
Get a Hash reference to all possible customers matching the given search
parameter, use "*" for all.

    my $Result = $iPhoneObject->CustomerSearch(
        Search          => 'sw',
        UserID          => 1,
    );

    # a result could be

    $Result = [
        Ray   => '"Ray Park" <rp@sw.com>',
        David => '"David Prowse" <dp@sw.com>',
    ],

=cut

sub CustomerSearch {
    my ( $Self, %Param ) = @_;

    # get AutoComplete settings form config
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('AutoComplete::Agent')->{Default};

    my %Customers;

    # search only if the search string is at least as long as the Minimum Query Length
    if ( length( $Param{Search} ) >= $Self->{Config}->{MinQueryLength} ) {
        %Customers = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerSearch(
            Search => $Param{Search},
        );
    }
    return \%Customers;
}

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
    my $UserTimeZone = $UserPreferences{UserTimeZone};

    my $UserTimeObject;

    if ( $Kernel::OM->Get('Kernel::Config')->Get('TimeZoneUser') && $UserTimeZone ) {
        $UserTimeObject = Kernel::System::Time->new( UserTimeZone => $UserTimeZone );
    }
    else {
        $UserTimeObject = $Kernel::OM->Get('Kernel::System::Time');
        $UserTimeZone   = '';
    }

    # set common parameters to be passes to helper functions
    $Param{UserTimeZone}   = $UserTimeZone;
    $Param{UserTimeObject} = $UserTimeObject;

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

=item VersionGet()
Get a Hash reference with information about the otrs iPhone Package extension

    my $Resut = $iPhoneObject->VersionGet(
        UserID => 1;
    );

    a result could be

    $Result = [
        Name    => "iPhoneHandle"
        Version => "0.9.2",
        Vendor  => "OTRS AG",
        URL     => "L<http://otrs.org/>",
    ];

=cut

sub VersionGet {
    my ( $Self, %Param ) = @_;

    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'No UserID given! Please contact the admin.',
        );
        return -1;
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get home path
    my $Home = $ConfigObject->Get('Home');

    # load RELEASE file
    if ( -e !"$Home/var/RELEASE.iPhoneHandle" ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "ERROR: $Home/var/RELEASE.iPhoneHandle does not exist! This file is"
                . " needed by iPhoneHandle, the system will not work without this file.\n",
        );
        return -1;
    }
    my $PackageName;
    my $PackageVersion;

    # read RELEASE file and store it as an array reference
    my $Product = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
        Location => "$Home/var/RELEASE.iPhoneHandle",
        Result   => "ARRAY",
    );

    # send and error if RELEASE file was not read
    if ( !$Product ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "ERROR: Can't read $Home/var/RELEASE.iPhoneHandle! This file is"
                . " needed by iPhoneHandle, the system will not work without this file.\n",
        );
        return -1;
    }

    # get PackageName and PackageVersion from RELEASE file
    for my $Line ( @{$Product} ) {

        # filtering of comment lines
        if ( $Line !~ m{\A \#}msx ) {
            if ( $Line =~ m{\A PRODUCT \s{0,2} = \s{0,2} (.*) \s{0,2} \z}msxi ) {
                $PackageName = $1;
            }
            elsif ( $Line =~ m{\A VERSION \s{0,2} = \s{0,2} (.*) \s{0,2} \z}msxi ) {
                $PackageVersion = $1;
            }
        }
    }

    return {
        Name      => $PackageName,
        Version   => $PackageVersion,
        Vendor    => 'OTRS AG',
        URL       => 'http://otrs.org/',
        Framework => $ConfigObject->Get('Version'),
    };
}

=item CustomerIDGet()
Get the Customer ID from a given customer login

    my $Resut = $iPhoneObject->CustomerIDGet(
        CustomerUserID => "David";
    );

    a result could be

    $Result = "sw"

=cut

sub CustomerIDGet {
    my ( $Self, %Param ) = @_;

    # check for parameters
    if ( !$Param{CustomerUserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need CustomerUserID!',
        );
        return -1;
    }
    my $CustomerID;

    # get customer data
    my %CustomerUserData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
        User => $Param{CustomerUserID},
    );
    if ( %CustomerUserData && $CustomerUserData{UserCustomerID} ) {
        $CustomerID = $CustomerUserData{UserCustomerID};
        return $CustomerID;
    }
    else {
        return '';
    }
}

=item ArticleIndex()

returns an array with article id's or '' if ticket has no articles

    my @ArticleIDs = $iPhoneObject->ArticleIndex(
        TicketID => 123,
    );

    my @ArticleIDs = $iPhoneObject->ArticleIndex(
        SenderType => 'customer',
        TicketID   => 123,
    );

=cut

sub ArticleIndex {
    my ( $Self, %Param ) = @_;

    my @Index = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleIndex(%Param);

    return @Index;
}

=item InitConfigGet()

returns a hash reference with initial configuration required by the iPhone App

    my $Result = $iPhoneObject->InitConfigGet(
        UserID => 1,
    );

    a result could be

    $Result = [
        TicketResponsible          => 1,
        TicketWatcher              => 1,
        CurrentTimestamp           => "2010-10-26 11:53:35",
        VersionGet                 => {
            URL       => "http://otrs.org/",
            Framework => "3.3.x git",
            Version   => "0.9.6",
            Vendor    => "OTRS AG",
            Name      => "iPhoneHandle"
        },
        CustomerSearchAutoComplete => {
            QueryDelay          => 0.1,
            Active              => 1,
            MaxResultsDisplayed => 20,
            TypeAhead           => false,
            MinQueryLength      => 3,
        },
        DefaultCharset             => "utf-8",
    ];

=cut

sub InitConfigGet {
    my ( $Self, %Param ) = @_;

    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'No UserID given! Please contact the admin.',
        );
        return -1;
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my %InitConfig;

    $InitConfig{TicketWatcher}     = $ConfigObject->Get('Ticket::Watcher');
    $InitConfig{TicketResponsible} = $ConfigObject->Get('Ticket::Responsible');
    $InitConfig{DefaultCharset}    = $ConfigObject->Get('DefaultCharset');
    $InitConfig{CustomerSearchAutoComplete}
        = $ConfigObject->Get('AutoComplete::Agent')->{Default};
    $InitConfig{CurrentTimestamp} = $Kernel::OM->Get('Kernel::System::Time')->CurrentTimestamp();
    $InitConfig{VersionGet}       = $Self->VersionGet(%Param);

    return \%InitConfig;
}

# internal subroutines

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

sub _GetScreenElements {
    my ( $Self, %Param ) = @_;

    my @ScreenElements;

    # use language object from the param
    my $LanguageObject = $Param{LanguageObject};

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

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

    my $UserTimeZone = $Param{UserTimeZone} || '';

    # transform pending time, time stamp based on user time zone
    if ( IsStringWithData( $Param{PendingDate} ) ) {
        $Param{PendingDate} = $Self->_TransformDateSelection(
            TimeStamp      => $Param{PendingDate},
            UserTimeZone   => $UserTimeZone,
            UserTimeObject => $Param{UserTimeObject},
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
            UserTimeZone       => $UserTimeZone || 0,
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

    my $UserTimeZone = $Param{UserTimeZone} || '';

    # transform pending time, time stamp based on user time zone
    if ( IsStringWithData( $Param{PendingDate} ) ) {
        $Param{PendingDate} = $Self->_TransformDateSelection(
            TimeStamp      => $Param{PendingDate},
            UserTimeZone   => $UserTimeZone,
            UserTimeObject => $Param{UserTimeObject},
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
            UserTimeZone       => $UserTimeZone || 0,
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
            $Param{Subject} = $Self->{Config}->{Subject},;
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

    my $UserTimeZone = $Param{UserTimeZone} || '';

    # transform pending time, time stamp based on user time zone
    if ( IsStringWithData( $Param{PendingDate} ) ) {
        $Param{PendingDate} = $Self->_TransformDateSelection(
            TimeStamp      => $Param{PendingDate},
            UserTimeZone   => $UserTimeZone,
            UserTimeObject => $Param{UserTimeObject},
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
            UserTimeZone       => $UserTimeZone || 0,
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

    my $UserTimeZone = $Param{UserTimeZone} || '';

    # transform pending time, time stamp based on user time zone
    if ( IsStringWithData( $Param{PendingDate} ) ) {
        $Param{PendingDate} = $Self->_TransformDateSelection(
            TimeStamp      => $Param{PendingDate},
            UserTimeZone   => $UserTimeZone,
            UserTimeObject => $Param{UserTimeObject},
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
            UserTimeZone       => $UserTimeZone || 0,
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
    my $Wrote      = $Param{LanguageObject}->Get('wrote');
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

sub _TransformDateSelection {
    my ( $Self, %Param ) = @_;

    # time zone translation if needed
    if ( $Kernel::OM->Get('Kernel::Config')->Get('TimeZoneUser') && $Param{UserTimeZone} ) {
        my $SystemTime = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
            String => $Param{TimeStamp},
        );
        $SystemTime = $SystemTime - ( $Param{UserTimeZone} * 3600 );
        $Param{TimeStamp}
            = $Param{UserTimeObject}->SystemTime2TimeStamp( SystemTime => $SystemTime, );
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
