# --
# Kernel/System/DynamicField/Driver/iPhoneDateTime.pm - Driver for DynamicField DateTime backend
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::iPhoneDateTime;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Time',
);

=head1 NAME

Kernel::System::DynamicField::Driver::iPhoneDateTime

=head1 SYNOPSIS

DynamicFields DateTime backend driver for iPhoneHandle

=head1 PUBLIC INTERFACE

This module implements the public interface of L<Kernel::System::DynamicField::Backend>.
Please look there for a detailed reference of the functions.

=over 4

=cut

sub IPhoneFieldParameterBuild {
    my ( $Self, %Param ) = @_;

    # take config from field config
    my $FieldConfig = $Param{DynamicFieldConfig}->{Config};
    my $FieldName   = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};
    my $FieldLabel  = $Param{LanguageObject}->Get( $Param{DynamicFieldConfig}->{Label} );

    my $Value = '';

    # set the field value or default
    if ( $Param{UseDefaultValue} ) {
        my $TimeDiff = ( defined $FieldConfig->{DefaultValue} ? $FieldConfig->{DefaultValue} : 0 );

        # get time object
        my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

        # get current system time
        my $SystemTime = $TimeObject->SystemTime();

        # get time string + $Time diff
        $Value = $TimeObject->SystemTime2TimeStamp(
            SystemTime => $SystemTime + $TimeDiff,
        );
    }
    $Value = $Param{Value} if defined $Param{Value};

    # create the field definition
    my $Data = {
        Name      => $FieldName,
        Title     => $FieldLabel,
        Datatype  => 'DateTime',
        Viewtype  => 'Picker',
        Mandatory => $Param{Mandatory},
        Default   => $Value || '',
    };

    return $Data;
}

sub IPhoneFieldValueGet {
    my ( $Self, %Param ) = @_;

    my $FieldName = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};

    my $Value = $Param{$FieldName};

    # time zone translation if needed
    if (
        $Kernel::OM->Get('Kernel::Config')->Get('TimeZoneUser')
        && $Param{UserTimeZone}
        && $Value
        )
    {

        $Kernel::OM->ObjectsDiscard( Objects => ['Kernel::System::Time'] );

        # covert $Value to a numeric time for conversions
        my $SystemTime = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
            String => $Value,
        );

        # create a time object for the user (because of the time zone)
        $Kernel::OM->ObjectsDiscard( Objects => ['Kernel::System::Time'], );
        $Kernel::OM->ObjectParamAdd(
            'Kernel::System::Time' => {
                UserTimeZone => $Param{UserTimeZone},
            },
        );

        # subtract the user time zone from the current value
        $SystemTime = $SystemTime - ( $Param{UserTimeZone} * 3600 );

        # convert numeric value again to string
        $Value = $Kernel::OM->Get('Kernel::System::Time')->SystemTime2TimeStamp(
            SystemTime => $SystemTime,
        );
    }

    return $Value;
}

sub IPhoneFieldValueValidate {
    my ( $Self, %Param ) = @_;

    # get the field value from param
    my $Value = $Param{Value};

    my $ServerError;
    my $ErrorMessage;

    # perform necessary validations
    if ( $Param{Mandatory} && $Value eq '' ) {

        return {
            ServerError  => 1,
            ErrorMessage => $ErrorMessage,
        };
    }

    # try to convert value to a SystemTime
    if ($Value) {
        my $SystemTime = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
            String => $Value,
        );

        if ( !$SystemTime ) {
            return {
                ServerError  => 1,
                ErrorMessage => $ErrorMessage,
            };
        }
    }

    # create resulting structure
    my $Result = {
        ServerError  => $ServerError,
        ErrorMessage => $ErrorMessage,
    };

    return $Result;
}

sub _TransformDateSelection {
    my ( $Self, %Param ) = @_;

    # time zone translation if needed
    if ( $Kernel::OM->Get('Kernel::Config')->Get('TimeZoneUser') && $Param{UserTimeZone} ) {

        $Kernel::OM->ObjectsDiscard( Objects => ['Kernel::System::Time'] );
        my $SystemTime = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
            String => $Param{TimeStamp},
        );
        $SystemTime = $SystemTime - ( $Self->{UserTimeZone} * 3600 );

        # create a time object for the user (because of the time zone)
        $Kernel::OM->ObjectsDiscard( Objects => ['Kernel::System::Time'] );
        $Kernel::OM->ObjectParamAdd(
            'Kernel::System::Time' => {
                UserTimeZone => $Param{UserTimeZone},
            },
        );

        $Param{TimeStamp} = $Kernel::OM->Get('Kernel::System::Time')->SystemTime2TimeStamp(
            SystemTime => $SystemTime,
        );
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
