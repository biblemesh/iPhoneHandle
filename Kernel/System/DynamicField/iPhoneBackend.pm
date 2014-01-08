# --
# Kernel/System/DynamicField/iPhoneBackend.pm - Interface for DynamicField backends
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::iPhoneBackend;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

=head1 NAME

Kernel::System::DynamicField::iPhoneBackend

=head1 SYNOPSIS

DynamicFields backend interface for iPhone

=head1 PUBLIC INTERFACE

=over 4

=cut

=item IPhoneFieldParameterBuild()

creates the field definition to be used in iphone edit masks.

    my $FieldDefinition = $BackendObject->IPhoneFieldParameterBuild(
        DynamicFieldConfig   => $DynamicFieldConfig,      # Complete config of the DynamicField
        Value                => 'Any value',              # Optional
        Mandatory            => 1,                        # 0 or 1,
        UseDefaultValue      => 1,                        # 0 or 1, 1 default
        OverridePossibleNone => 1,                        # Optional, 0 or 1. If defined orverrides the Possible None
                                                          #     setting of all dynamic fields (where applies) with the
                                                          #     defined value
        LanguageObject       => $LanguageObject,
    );

    Returns:

        my $FieldDefinition = {
            Name           => 'some name',      # Field name 'DyanmicField_NameX'

            Title          => 'some title',     # Field label (translated if capable)

            Datatype       => $Datatype,        # The type of that to hold, Options:
                                                #    Date || Time || DateTime || Text
                                                #    || Numeric

            Viewtype       => $ViewType,        # The format of the field in the iPhone App
                                                #    AutoCompletion (input field with an
                                                #       auto-completion feature; possible values
                                                #       are loaded dynamically from the server with
                                                #       the DynamicOptions)
                                                #    Picker (option list with values which are
                                                #       provided with the Options or DynamicOptions
                                                #       attribute)
                                                #    EMail (input field for E-Mail addresses with a
                                                #       suitable keyboard)
                                                #    URL (input field for URLs with a suitable
                                                #       keyboard)
                                                #    Password (input field for passwords, which does
                                                #       not reveal the entered text)
                                                #    Input (simple input field)
                                                #    TextArea (multi-line input field)

            Min             => 1,               # Optional, Minimum value for numeric form fields
                                                #    or minimum length for text fields.

            Max             => 2,               # Optional, Maximum value for numeric form fields or
                                                #    maximum length for text fields.

            Options         => {                # Optional, List of options which defines the range
                1 => 'Value1',                  #    of values for an element of Viewtype Picker.
                2 => 'Value2',                  #    Options is not required for picker elements
            },                                  #    with Datatype Date, Time or DateTime.
                                                #    Mandatory if the Datatype is not Date,
                                                #    Time und DateTime, the Viewtype is Picker and
                                                #    DyynamicOptions is not provided

            DynamicOptions => {                 # Optional, Similar to Options but the list of
                Object     => 'some object',    #    values is not fixed, instead a function is
                Method     => 'some method',    #    called to retreive the possible options.
                Parameters => [                 #    DynamicOptions is not required for picker
                    {                           #    elements with Datatype Date, Time or DateTime.
                        Param1 => 'some data',  #    Mandatory if the Datatype is not Date,
                        Param2 => 'some data',  #    Time und DateTime, the Viewtype is Picker and
                    },                          #    DyynamicOptions is not provided
                ],
            },

            AutoFillElements => [               # Optional, Used to set another field value
                {
                    ElementName => 'field name',
                    Object      => 'some object',
                    Method      => 'some method',
                    Parameters  => [
                        {
                            Param1 => 'some data',
                        },
                    ],
                },
            ],

            Mandatory => 0,                     # 0 || 1

            Default   => 'some value',
        };
    };

=cut

sub IPhoneFieldParameterBuild {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(DynamicFieldConfig LanguageObject)) {
        if ( !$Param{$Needed} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $Needed!" );
            return;
        }
    }

    # check DynamicFieldConfig (general)
    if ( !IsHashRefWithData( $Param{DynamicFieldConfig} ) ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "The field configuration is invalid",
        );
        return;
    }

    # check DynamicFieldConfig (internally)
    for my $Needed (qw(ID FieldType ObjectType Config Name)) {
        if ( !$Param{DynamicFieldConfig}->{$Needed} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Needed in DynamicFieldConfig!"
            );
            return;
        }
    }

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    # set use default value as default if not specified
    if ( !defined $Param{UseDefaultValue} ) {
        $Param{UseDefaultValue} = 1;
    }

    # verify if function is available
    return if !$Self->{$DynamicFieldBackend}->can('IPhoneFieldParameterBuild');

    # call IPhoneFieldParameterBuild on the specific backend
    my $FieldDefinition = $Self->{$DynamicFieldBackend}->IPhoneFieldParameterBuild(%Param);

    return $FieldDefinition;

}

=item IPhoneFieldValueGet()

extracts the value of a dynamic field from the param object.

    my $Value = $BackendObject->IPhoneFieldValueGet(
        DynamicFieldConfig   => $DynamicFieldConfig,    # complete config of the DynamicField
        DynamicField_NameX   => 'DynamicFieldValue',    # Raw field value where, NameX is the name
                                                        #     of the filed
        UserTimeZone         => -6,
    );

    Returns $Value;                                     # depending on each field type e.g.
                                                        #   $Value = 'a text';
                                                        #   $Value = '1977-12-12 12:00:00';
                                                        #   $Value = 1;

=cut

sub IPhoneFieldValueGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(DynamicFieldConfig)) {
        if ( !$Param{$Needed} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $Needed!" );
            return;
        }
    }

    # define transform dates parameter
    if ( !defined $Param{TransformDates} ) {
        $Param{TransformDates} = 1;
    }

    # check DynamicFieldConfig (general)
    if ( !IsHashRefWithData( $Param{DynamicFieldConfig} ) ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "The field configuration is invalid",
        );
        return;
    }

    # check DynamicFieldConfig (internally)
    for my $Needed (qw(ID FieldType ObjectType Name)) {
        if ( !$Param{DynamicFieldConfig}->{$Needed} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Needed in DynamicFieldConfig!"
            );
            return;
        }
    }

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    # verify if function is available
    return if !$Self->{$DynamicFieldBackend}->can('IPhoneFieldValueGet');

    # return value from the specific backend
    return $Self->{$DynamicFieldBackend}->IPhoneFieldValueGet(%Param);
}

=item IPhoneFieldValueValidate()

validate the current value for the dynamic field

    my $Result = $BackendObject->IPhoneFieldValueValidate(
        DynamicFieldConfig   => $DynamicFieldConfig,      # complete config of the DynamicField
        Value                => $Value,                   # The current dynamic field value
        Mandatory            => 1,                        # 0 or 1,
    );

    Returns

    $Result = {
        ServerError        => 1,                          # 0 or 1,
        ErrorMessage       => $ErrorMessage,              # Optional or a default will be used in error case
    }

=cut

sub IPhoneFieldValueValidate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{DynamicFieldConfig} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => "Need DynamicFieldConfig!" );
        return;
    }

    # check DynamicFieldConfig (general)
    if ( !IsHashRefWithData( $Param{DynamicFieldConfig} ) ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "The field configuration is invalid",
        );
        return;
    }

    # check DynamicFieldConfig (internally)
    for my $Needed (qw(ID FieldType ObjectType Config Name)) {
        if ( !$Param{DynamicFieldConfig}->{$Needed} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Needed in DynamicFieldConfig!"
            );
            return;
        }
    }

    # set the dynamic field specific backend
    my $DynamicFieldBackend = 'DynamicField' . $Param{DynamicFieldConfig}->{FieldType} . 'Object';

    if ( !$Self->{$DynamicFieldBackend} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Backend $Param{DynamicFieldConfig}->{FieldType} is invalid!"
        );
        return;
    }

    # verify if function is available
    return if !$Self->{$DynamicFieldBackend}->can('IPhoneFieldValueValidate');

    # return validation structure from the specific backend
    return $Self->{$DynamicFieldBackend}->IPhoneFieldValueValidate(%Param);

}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
