# --
# Kernel/System/DynamicField/Driver/iPhoneDate.pm - Driver for DynamicField Date backend
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::iPhoneDate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Time'
);

=head1 NAME

Kernel::System::DynamicField::Driver::iPhoneDate

=head1 SYNOPSIS

DynamicFields Date backend driver for iPhoneHandle

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
    my $FieldLabel  = $Param{LanguageObject}->Translate( $Param{DynamicFieldConfig}->{Label} );

    my $Value = '';

    # set the field value or default
    if ( $Param{UseDefaultValue} ) {
        my $TimeDiff = $FieldConfig->{DefaultValue} // 0;

        if ( $TimeDiff eq '' ) {
            $TimeDiff = 0;
        }

        # get time object
        my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

        # get current system time
        my $SystemTime = $TimeObject->SystemTime();

        # get time string + $Time diff
        $Value = $TimeObject->SystemTime2TimeStamp(
            SystemTime => $SystemTime + $TimeDiff,
        );

        # remove the time part
        $Value =~ s{\A (\d{4}-\d{2}-\d{2})  .* \z}{$1}xms;
    }
    $Value = $Param{Value} if defined $Param{Value};

    # create the field definition
    my $Data = {
        Name      => $FieldName,
        Title     => $FieldLabel,
        Datatype  => 'Date',
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

    # remove the time part
    if ($Value) {
        $Value =~ s{\A (\d{4}-\d{2}-\d{2})  .* \z}{$1}xms;

        # add 0s to the time part
        $Value .= ' 00:00:00';
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

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
