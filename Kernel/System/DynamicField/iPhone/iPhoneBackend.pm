# --
# Kernel/System/DynamicField/iPhone/iPhoneBackend.pm - Interface for DynamicField backends
# Copyright (C) 2001-2012 OTRS AG, http://otrs.org/
# --
# $Id: iPhoneBackend.pm,v 1.2 2012-04-18 19:52:06 cr Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::iPhone::iPhoneBackend;

use strict;
use warnings;

use Scalar::Util qw(weaken);
use Kernel::System::VariableCheck qw(:all);

use vars qw($VERSION);
$VERSION = qw($Revision: 1.2 $) [1];

=head1 NAME

Kernel::System::DynamicField::Backend

=head1 SYNOPSIS

DynamicFields backend interface

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a DynamicField iPhone backend object

    use Kernel::Config;
    use Kernel::System::Encode;
    use Kernel::System::Log;
    use Kernel::System::Time;
    use Kernel::System::Main;
    use Kernel::System::DB;
    use Kernel::System::DynamicField::iPhone::iPhoneBackend;

    my $ConfigObject = Kernel::Config->new();
    my $EncodeObject = Kernel::System::Encode->new(
        ConfigObject => $ConfigObject,
    );
    my $LogObject = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
    );
    my $TimeObject = Kernel::System::Time->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
    );
    my $MainObject = Kernel::System::Main->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
        LogObject    => $LogObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
    );
    my $iPhoneBackendObject = Kernel::System::DynamicField::iPhone::iPhoneBackend->new(
        ConfigObject        => $ConfigObject,
        EncodeObject        => $EncodeObject,
        LogObject           => $LogObject,
        TimeObject          => $TimeObject,
        MainObject          => $MainObject,
        DBObject            => $DBObject,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    for my $Needed (qw(ConfigObject EncodeObject LogObject MainObject DBObject TimeObject)) {
        die "Got no $Needed!" if !$Param{$Needed};

        $Self->{$Needed} = $Param{$Needed};
    }

    # get the Dynamic Field Backends configuration
    my $DynamicFieldsConfig = $Self->{ConfigObject}->Get('DynamicFields::iPhone::Backend');

    # check Configuration format
    if ( !IsHashRefWithData($DynamicFieldsConfig) ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Dynamic field configuration is not valid!",
        );
        return;
    }

    # create all registered backend modules
    for my $FieldType ( sort keys %{$DynamicFieldsConfig} ) {

        # check if the registration for each field type is valid
        if ( !$DynamicFieldsConfig->{$FieldType}->{Module} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Registration for field type $FieldType is invalid!",
            );
            return;
        }

        # set the backend file
        my $BackendModule = $DynamicFieldsConfig->{$FieldType}->{Module};

        # check if backend field exists
        if ( !$Self->{MainObject}->Require($BackendModule) ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Can't load dynamic field backend module for field type $FieldType!",
            );
            return;
        }

        # create a backend object
        my $BackendObject = $BackendModule->new( %{$Self} );

        if ( !$BackendObject ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Couldn't create a backend object for field type $FieldType!",
            );
            return;
        }

        if ( ref $BackendObject ne $BackendModule ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Backend object for field type $FieldType was not created successfuly!",
            );
            return;
        }

        # remember the backend object
        $Self->{ 'DynamicField' . $FieldType . 'Object' } = $BackendObject;
    }

    # get the Dynamic Field Objects configuration
    my $DynamicFieldObjectTypeConfig = $Self->{ConfigObject}->Get('DynamicFields::ObjectType');

    # check Configuration format
    if ( IsHashRefWithData($DynamicFieldObjectTypeConfig) ) {

        # create all registered ObjectType handler modules
        for my $ObjectType ( sort keys %{$DynamicFieldObjectTypeConfig} ) {

            # check if the registration for each field type is valid
            if ( !$DynamicFieldObjectTypeConfig->{$ObjectType}->{Module} ) {
                $Self->{LogObject}->Log(
                    Priority => 'error',
                    Message  => "Registration for object type $ObjectType is invalid!",
                );
                return;
            }

            # set the backend file
            my $ObjectHandlerModule = $DynamicFieldObjectTypeConfig->{$ObjectType}->{Module};

            # check if backend field exists
            if ( !$Self->{MainObject}->Require($ObjectHandlerModule) ) {
                $Self->{LogObject}->Log(
                    Priority => 'error',
                    Message =>
                        "Can't load dynamic field object handler module for object type $ObjectType!",
                );
                return;
            }

            # create a backend object
            my $ObjectHandlerObject = $ObjectHandlerModule->new(
                %{$Self},
                %Param,    # pass %Param too, for optional arguments like TicketObject
            );

            if ( !$ObjectHandlerObject ) {
                $Self->{LogObject}->Log(
                    Priority => 'error',
                    Message  => "Couldn't create a handler object for object type $ObjectType!",
                );
                return;
            }

            if ( ref $ObjectHandlerObject ne $ObjectHandlerModule ) {
                $Self->{LogObject}->Log(
                    Priority => 'error',
                    Message =>
                        "Handler object for object type $ObjectType was not created successfuly!",
                );
                return;
            }

            # remember the backend object
            $Self->{ 'DynamicField' . $ObjectType . 'HandlerObject' } = $ObjectHandlerObject;
        }
    }

    return $Self;
}

=item IsIPhoneCapable()

returns if the current field backend is supported by the iPhone App.

    my $iPhoneCapable = $iPhoneBackendObject->IsIPhoneCapable();   # 1 or 0

=cut

sub IsIPhoneCapable {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(DynamicFieldConfig)) {
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
    for my $Needed (qw(ID FieldType ObjectType)) {
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

    # call IsIPhoneCapable on the specific backend
    return $Self->{$DynamicFieldBackend}->IsIPhoneCapable(
        %Param
    );
}

=item EditFieldRender()

creates the field definition to be used in iphone edit masks.

    my $FieldDefinition = $iPhoneBackendObject->EditFieldRender(
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
            Name           => 'some name',      # Field name

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

sub EditFieldRender {
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

    # call EditFieldRender on the specific backend
    my $FieldDefinition = $Self->{$DynamicFieldBackend}->EditFieldRender(
        %Param
    );

    return $FieldDefinition;

}

=item EditFieldValueGet()

extracts the value of a dynamic field from the param object.

    my $Value = $iPhoneBackendObject->EditFieldValueGet(
        DynamicFieldConfig   => $DynamicFieldConfig,    # complete config of the DynamicField
        DynamicField_NameX   => 'DynamicFieldValue'     # Raw field value where, NameX is the name
                                                        #     of the filed
        TransformDates       => 1                       # 1 || 0, default 1, to transform the dynamic fields that
                                                        #   use dates to the user time zone (i.e. Date, DateTime
                                                        #   dynamic fields)
        UserTimeZone         => -6
    );

    Returns $Value;                                     # depending on each field type e.g.
                                                        #   $Value = 'a text';
                                                        #   $Value = '1977-12-12 12:00:00';
                                                        #   $Value = 1;

=cut

sub EditFieldValueGet {
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

    # return value from the specific backend
    return $Self->{$DynamicFieldBackend}->EditFieldValueGet(%Param);
}

=item EditFieldValueValidate()

validate the current value for the dynamic field

    my $Result = $iPhoneBackendObject->EditFieldValueValidate(
        DynamicFieldConfig   => $DynamicFieldConfig,      # complete config of the DynamicField
        Value                => $$Value                   # The current dynamic field value
        Mandatory            => 1,                        # 0 or 1,
    );

    Returns

    $Result = {
        ServerError        => 1,                          # 0 or 1,
        ErrorMessage       => $ErrorMessage,              # Optional or a default will be used in error case
    }

=cut

sub EditFieldValueValidate {
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

    # return validation structure from the specific backend
    return $Self->{$DynamicFieldBackend}->EditFieldValueValidate(%Param);

}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut

=head1 VERSION

$Revision: 1.2 $ $Date: 2012-04-18 19:52:06 $

=cut
