# --
# Kernel/System/DynamicField/Driver/iPhoneDropdown.pm - Driver for DynamicField Dropdown backend
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::iPhoneDropdown;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

=head1 NAME

Kernel::System::DynamicField::Driver::iPhoneDropdown

=head1 SYNOPSIS

DynamicFields Dropdown backend driver for iPhoneHandle

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
        $Value = ( defined $FieldConfig->{DefaultValue} ? $FieldConfig->{DefaultValue} : '' );
    }
    $Value = $Param{Value} if defined $Param{Value};

    # set PossibleValues
    my $PossibleValues = $FieldConfig->{PossibleValues};

    if ( $FieldConfig->{TranslatableValues} ) {
        if ( IsHashRefWithData($PossibleValues) ) {
            for my $PossibleKey ( sort keys %{$PossibleValues} ) {
                my $OriginalValue = $PossibleValues->{$PossibleKey};
                $PossibleValues->{$PossibleKey}
                    = $Param{LanguageObject}->Translate($OriginalValue) || $OriginalValue;
            }
        }
    }

    # set PossibleNone attribute
    my $FieldPossibleNone;
    if ( defined $Param{OverridePossibleNone} ) {
        $FieldPossibleNone = $Param{OverridePossibleNone};
    }
    else {
        $FieldPossibleNone = $FieldConfig->{PossibleNone} || 0;
    }

    if ($FieldPossibleNone) {
        $PossibleValues->{''} = '-';
    }

    # create the field definition
    my $Data = {
        Name      => $FieldName,
        Title     => $FieldLabel,
        Datatype  => 'Text',
        Viewtype  => 'Picker',
        Options   => $PossibleValues,
        Mandatory => $Param{Mandatory},
        Default   => $Value || '',
    };

    return $Data;
}

sub IPhoneFieldValueGet {
    my ( $Self, %Param ) = @_;

    my $FieldName = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};

    my $Value = $Param{$FieldName};

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
        $ServerError = 1;
    }
    else {

        # get possible values list
        my $PossibleValues = $Param{DynamicFieldConfig}->{Config}->{PossibleValues};

        # validate if value is in possible values list (but let pass empty values)
        if ( $Value && !$PossibleValues->{$Value} ) {
            $ServerError  = 1;
            $ErrorMessage = 'The field content is invalid';
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
