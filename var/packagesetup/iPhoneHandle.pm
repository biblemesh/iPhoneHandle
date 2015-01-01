# --
# iPhoneHandle.pm - code to execute during package installation
# Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package var::packagesetup::iPhoneHandle;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Package',
    'Kernel::System::SysConfig',
);

=head1 NAME

iPhoneHandle.pm - code to execute during package installation

=head1 SYNOPSIS

All functions

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object


create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $CodeObject = $Kernel::OM->Get('var::packagesetup::iPhoneHandle');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # rebuild ZZZ* files
    $Kernel::OM->Get('Kernel::System::SysConfig')->WriteDefault();

    # define the ZZZ files
    my @ZZZFiles = (
        'ZZZAAuto.pm',
        'ZZZAuto.pm',
    );

    # reload the ZZZ files (mod_perl workaround)
    for my $ZZZFile (@ZZZFiles) {

        PREFIX:
        for my $Prefix (@INC) {
            my $File = $Prefix . '/Kernel/Config/Files/' . $ZZZFile;
            next PREFIX if !-f $File;
            do $File;
            last PREFIX;
        }
    }

    # always discard the config object before package code is executed,
    # to make sure that the config object will be created newly, so that it
    # will use the recently written new config from the package
    $Kernel::OM->ObjectsDiscard(
        Objects => ['Kernel::Config'],
    );

    return $Self;
}

=item CodeInstall()

run the code install part

    my $Result = $CodeObject->CodeInstall();

=cut

sub CodeInstall {
    my ( $Self, %Param ) = @_;

    $Self->_UpdateReleaseFile();

    return 1;
}

=item CodeReinstall()

run the code reinstall part

    my $Result = $CodeObject->CodeReinstall();

=cut

sub CodeReinstall {
    my ( $Self, %Param ) = @_;

    $Self->_UpdateReleaseFile();
    $Self->_MigrateConfigurations();

    return 1;
}

=item CodeUpgrade()

run the code upgrade part

    my $Result = $CodeObject->CodeUpgrade();

=cut

sub CodeUpgrade {
    my ( $Self, %Param ) = @_;

    $Self->_UpdateReleaseFile();
    $Self->_MigrateConfigurations();

    return 1;
}

=item CodeUninstall()

run the code uninstall part

    my $Result = $CodeObject->CodeUninstall();

=cut

sub CodeUninstall {
    my ( $Self, %Param ) = @_;

    $Self->_RemoveReleaseFile();

    return 1;
}

=item _UpdateReleaseFile()

creates or updates RELEASE.iPhoneHandle file

    my $Result = $CodeObject->_UpdateReleaseFile();

=cut

sub _UpdateReleaseFile {
    my ( $Self, %Param ) = @_;

    my $PackageVersion;

    # get package object
    my $PackageObject = $Kernel::OM->Get('Kernel::System::Package');

    # get the installed version of iPhoneHandle package
    PACKAGE:
    for my $Package ( $PackageObject->RepositoryList() ) {
        if ( $Package->{Name}->{Content} eq 'iPhoneHandle' ) {
            $PackageVersion = $Package->{Version}->{Content};
            last PACKAGE;
        }
    }

    # if no iPhoneHandle package found and the code install is executed this must be a
    # development scenario
    if ( !$PackageVersion ) {
        $PackageVersion = 'git';
    }

    # get home path
    my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');

    # create or overwrite RELEASE.iPhoneHandle file
    my $Content      = "PRODUCT = iPhoneHandle\nVERSION = $PackageVersion";
    my $FileLocation = $Kernel::OM->Get('Kernel::System::Main')->FileWrite(
        Location => "$Home/var/RELEASE.iPhoneHandle",
        Content  => \$Content,
    );

    if ( !$FileLocation ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "ERROR: Can't write $Home/var/RELEASE.iPhoneHandle!.\n",
        );

        return -1;
    }

    # check RELEASE file
    if ( !-e "$Home/var/RELEASE.iPhoneHandle" ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "File $Home/var/RELEASE.iPhoneHandle was not created!.\n",
        );
    }

    return 1;
}

=item _RemoveReleaseFile()

removes RELEASE.iPhoneHandle file from the file system

    my $Result = $CodeObject->_RemoveReleaseFile();

=cut

sub _RemoveReleaseFile {
    my ( $Self, %Param ) = @_;

    # get home path
    my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');

    # delete RELEASE file
    if ( -e "$Home/var/RELEASE.iPhoneHandle" ) {
        if ( !unlink "$Home/var/RELEASE.iPhoneHandle" ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "File $Home/var/RELEASE.iPhoneHandle could not be deleted!.\n",
            );
        }

        return -1;
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "File $Home/var/RELEASE.iPhoneHandle was already deleted!.\n",
        );
    }

    return 1;
}

=item _MigrateConfigurations()

migrates old TicketFreeText, TicketFreeTime and ArticleFreeText configurations to new Dynamic
Fields Configurations

    my $Result = $CodeObject->_MigrateConfigurations();

=cut

sub _MigrateConfigurations {
    my ( $Self, %Param ) = @_;

    my @Screens = (
        'iPhone::Frontend::AgentTicketPhone',
        'iPhone::Frontend::AgentTicketNote',
        'iPhone::Frontend::AgentTicketClose',
        'iPhone::Frontend::AgentTicketCompose',
        'iPhone::Frontend::AgentTicketMove',
    );

    my @FreeFieldTypes = (
        'TicketFreeText',
        'TicketFreeTime',
        'ArticleFreeText',
    );

    SCREEN:
    for my $Screen (@Screens) {

        my $ScreenConfig = $Kernel::OM->Get('Kernel::Config')->Get($Screen);

        # skip screen if Dynamic Fields are already defined
        next SCREEN if IsHashRefWithData( $ScreenConfig->{DynamicField} );

        my %FieldsToAdd;

        # gather all free fields for this screen
        for my $FreeFieldType (@FreeFieldTypes) {

            # check if FreeFieldType configuration is set and get the configured fields
            if ( IsHashRefWithData( $ScreenConfig->{$FreeFieldType} ) ) {

                FREEFIELD:
                for my $FreeField ( sort keys %{ $ScreenConfig->{$FreeFieldType} } ) {

                    # skip the FreeFields that are set to 0
                    next FREEFIELD if !$ScreenConfig->{$FreeFieldType}->{$FreeField};

                    # add field setting (1 or 2) to the FieldsToAdd hash
                    $FieldsToAdd{ $FreeFieldType . $FreeField } = $ScreenConfig->{$FreeFieldType}->{$FreeField};
                }
            }
        }

        # update DynamicField configuration for the screen and add the configured FreeFields
        if ( IsHashRefWithData( \%FieldsToAdd ) ) {
            my $Success = $Kernel::OM->Get('Kernel::System::SysConfig')->ConfigItemUpdate(
                Valid => 1,
                Key   => $Screen . '###DynamicField',
                Value => \%FieldsToAdd,
            );

            if ( !$Success ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Can't update DynamicField configuration for $Screen!.\n",
                );

                return -1;
            }
        }
    }

    return 1
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
