# --
# iPhoneHandle.pm - code to excecute during package installation
# Copyright (C) 2001-2013 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package var::packagesetup::iPhoneHandle;

use strict;
use warnings;

use Kernel::Config;
use Kernel::System::SysConfig;
use Kernel::System::Package;
use Kernel::System::VariableCheck qw(:all);

=head1 NAME

iPhoneHandle.pm - code to excecute during package installation

=head1 SYNOPSIS

All functions

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::Log;
    use Kernel::System::Main;
    use Kernel::System::Time;
    use Kernel::System::DB;
    use Kernel::System::XML;
    use var::packagesetup::iPhone;

    my $ConfigObject = Kernel::Config->new();
    my $LogObject    = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
    );
    my $MainObject = Kernel::System::Main->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
    );
    my $TimeObject = Kernel::System::Time->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
    );
    my $XMLObject = Kernel::System::XML->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        DBObject     => $DBObject,
        MainObject   => $MainObject,
    );
    my $CodeObject = var::packagesetup::iPhone->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
        TimeObject   => $TimeObject,
        DBObject     => $DBObject,
        XMLObject    => $XMLObject,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Object (
        qw(ConfigObject LogObject MainObject TimeObject DBObject XMLObject EncodeObject)
        )
    {
        $Self->{$Object} = $Param{$Object} || die "Got no $Object!";
    }

    # create needed sysconfig object
    $Self->{SysConfigObject} = Kernel::System::SysConfig->new( %{$Self} );

    # rebuild ZZZ* files
    $Self->{SysConfigObject}->WriteDefault();

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

    # create needed objects
    $Self->{ConfigObject}  = Kernel::Config->new();
    $Self->{PackageObject} = Kernel::System::Package->new(%Param);

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

    # get the installed version of iPhoneHandle package
    PACKAGE:
    for my $Package ( $Self->{PackageObject}->RepositoryList() ) {
        if ( $Package->{Name}->{Content} eq 'iPhoneHandle' ) {
            $PackageVersion = $Package->{Version}->{Content},
                last PACKAGE;
        }
    }

    # if no iPhoneHandle package found and the code install is executed this must be a
    # development scenario
    if ( !$PackageVersion ) {
        $PackageVersion = 'git';
    }

    # get home path
    my $Home = $Self->{ConfigObject}->Get('Home');

    # create or overwrite RELEASE.iPhoneHandle file
    if ( open( my $ReleaseFile, '>', "$Home/var/RELEASE.iPhoneHandle" ) ) {    ## no critic
        print $ReleaseFile "PRODUCT = iPhoneHandle\n";
        print $ReleaseFile "VERSION = $PackageVersion";
        close($ReleaseFile);
    }
    else {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "ERROR: Can't write $Home/var/RELEASE.iPhoneHandle!.\n",
        );
        return -1;
    }

    # check RELEASE file
    if ( !-e "$Home/var/RELEASE.iPhoneHandle" ) {
        $Self->{LogObject}->Log(
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
    my $Home = $Self->{ConfigObject}->Get('Home');

    # delete RELEASE file
    if ( -e "$Home/var/RELEASE.iPhoneHandle" ) {
        if ( !unlink "$Home/var/RELEASE.iPhoneHandle" ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "File $Home/var/RELEASE.iPhoneHandle could not be deleted!.\n",
            );
        }
        return -1;
    }
    else {
        $Self->{LogObject}->Log(
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

        my $ScreenConfig = $Self->{ConfigObject}->Get($Screen);

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
                    $FieldsToAdd{ $FreeFieldType . $FreeField }
                        = $ScreenConfig->{$FreeFieldType}->{$FreeField};
                }
            }
        }

        # update DynamicField configuration for the screen and add the configured FreeFields
        if ( IsHashRefWithData( \%FieldsToAdd ) ) {
            my $Success = $Self->{SysConfigObject}->ConfigItemUpdate(
                Valid => 1,
                Key   => $Screen . '###DynamicField',
                Value => \%FieldsToAdd,
            );

            if ( !$Success ) {
                $Self->{LogObject}->Log(
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
