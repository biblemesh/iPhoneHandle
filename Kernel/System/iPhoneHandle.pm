# --
# Kernel/System/iPhoneHandle.pm - all iPhone handle functions
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::iPhoneHandle;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::iPhoneHandle::ScreenConfig
    Kernel::System::iPhoneHandle::ScreenAction
    Kernel::System::iPhoneHandle::Overview
);

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
        %SLA = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSLAList(
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

    $InitConfig{TicketWatcher}              = $ConfigObject->Get('Ticket::Watcher');
    $InitConfig{TicketResponsible}          = $ConfigObject->Get('Ticket::Responsible');
    $InitConfig{DefaultCharset}             = $ConfigObject->Get('DefaultCharset');
    $InitConfig{CustomerSearchAutoComplete} = $ConfigObject->Get('AutoComplete::Agent')->{Default};
    $InitConfig{CurrentTimestamp} = $Kernel::OM->Get('Kernel::System::Time')->CurrentTimestamp();
    $InitConfig{VersionGet}       = $Self->VersionGet(%Param);

    return \%InitConfig;
}

# internal subroutines

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
