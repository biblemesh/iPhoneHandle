# --
# Kernel/System/iPhoneHandle/Overview.pm - Overview base class
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::iPhoneHandle::Overview;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Lock',
    'Kernel::System::Log',
    'Kernel::System::Queue',
    'Kernel::System::State',
    'Kernel::System::Ticket',
    'Kernel::System::Time',
);

=head1 NAME

Kernel::System::iPhoneHandle::Overview - sub module of Kernel::System::iPhoneHandle

=head1 SYNOPSIS

Overview common functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

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

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
