# --
# iPhoneFieldValueValidate.t - iPhoneFieldValueValidate backend tests
# Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

## no critic (Modules::RequireExplicitPackage)
use strict;
use warnings;
use utf8;
use vars (qw($Self));

# prevent used only once warning
use Kernel::System::ObjectManager;

use Kernel::System::VariableCheck qw(:all);

# theres is not really needed to add the dynamic fields for this test, we can define a static
# set of configurations
my %DynamicFieldConfigs = (
    Text => {
        ID            => 123,
        InternalField => 0,
        Name          => 'TextField',
        Label         => 'Owner',
        FieldOrder    => 123,
        FieldType     => 'Text',
        ObjectType    => 'Ticket',
        Config        => {
            DefaultValue => '',
            Link         => '',
        },
        ValidID    => 1,
        CreateTime => '2011-02-08 15:08:00',
        ChangeTime => '2011-06-11 17:22:00',
    },
    TextArea => {
        ID            => 123,
        InternalField => 0,
        Name          => 'TextAreaField',
        Label         => 'Owner',
        FieldOrder    => 123,
        FieldType     => 'TextArea',
        ObjectType    => 'Ticket',
        Config        => {
            DefaultValue => '',
            Rows         => '',
            Cols         => '',
        },
        ValidID    => 1,
        CreateTime => '2011-02-08 15:08:00',
        ChangeTime => '2011-06-11 17:22:00',
    },
    Checkbox => {
        ID            => 123,
        InternalField => 0,
        Name          => 'CheckboxField',
        Label         => 'Owner',
        FieldOrder    => 123,
        FieldType     => 'Checkbox',
        ObjectType    => 'Ticket',
        Config        => {
            DefaultValue => '',
        },
        ValidID    => 1,
        CreateTime => '2011-02-08 15:08:00',
        ChangeTime => '2011-06-11 17:22:00',
    },
    Dropdown => {
        ID            => 123,
        InternalField => 0,
        Name          => 'DropdownField',
        Label         => 'Owner',
        FieldOrder    => 123,
        FieldType     => 'Dropdown',
        ObjectType    => 'Ticket',
        Config        => {
            DefaultValue       => '',
            Link               => '',
            PossibleNone       => '',
            TranslatableValues => 1,
            PossibleValues     => {
                1 => 'Priority',
                2 => 'State',
            },
        },
        ValidID    => 1,
        CreateTime => '2011-02-08 15:08:00',
        ChangeTime => '2011-06-11 17:22:00',
    },
    Multiselect => {
        ID            => 123,
        InternalField => 0,
        Name          => 'MultiselectField',
        Label         => 'Owner',
        FieldOrder    => 123,
        FieldType     => 'Multiselect',
        ObjectType    => 'Ticket',
        Config        => {
            DefaultValue       => '',
            PossibleNone       => '',
            TranslatableValues => 1,
            PossibleValues     => {
                1 => 'Priority',
                2 => 'State',
            },
        },
        ValidID    => 1,
        CreateTime => '2011-02-08 15:08:00',
        ChangeTime => '2011-06-11 17:22:00',
    },
    DateTime => {
        ID            => 123,
        InternalField => 0,
        Name          => 'DateTimeField',
        Label         => 'Owner',
        FieldOrder    => 123,
        FieldType     => 'DateTime',
        ObjectType    => 'Ticket',
        Config        => {
            DefaultValue  => undef,
            Link          => '',
            YearsPeriod   => '',
            YearsInFuture => '',
            YearsInPast   => '',
        },
        ValidID    => 1,
        CreateTime => '2011-02-08 15:08:00',
        ChangeTime => '2011-06-11 17:22:00',
    },
    Date => {
        ID            => 123,
        InternalField => 0,
        Name          => 'DateField',
        Label         => 'Owner',
        FieldOrder    => 123,
        FieldType     => 'Date',
        ObjectType    => 'Ticket',
        Config        => {
            DefaultValue  => '',
            Link          => '',
            YearsPeriod   => '',
            YearsInFuture => '',
            YearsInPast   => '',
        },
        ValidID    => 1,
        CreateTime => '2011-02-08 15:08:00',
        ChangeTime => '2011-06-11 17:22:00',
    },
);

# define tests
my @Tests = (
    {
        Name   => 'DynamicField Text',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            Value              => 'Priority',
            Mandatory          => 0,
        },
        ExpectedResults => {
            ServerError  => undef,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField Text Empty',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            Value              => '',
            Mandatory          => 0,

        },
        ExpectedResults => {
            ServerError  => undef,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField Text Empty Mandatory',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            Value              => '',
            Mandatory          => 1,
        },
        ExpectedResults => {
            ServerError  => 1,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField TextArea',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            Value              => 'Priority',
            Mandatory          => 0,
        },
        ExpectedResults => {
            ServerError  => undef,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField TextArea Empty',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            Value              => '',
            Mandatory          => 0,

        },
        ExpectedResults => {
            ServerError  => undef,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField TextArea Empty Mandatory',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            Value              => '',
            Mandatory          => 1,
        },
        ExpectedResults => {
            ServerError  => 1,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField Checkbox',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Checkbox},
            Value              => 1,
            Mandatory          => 0,
        },
        ExpectedResults => {
            ServerError  => undef,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField Checkbox Empty',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Checkbox},
            Value              => 0,
            Mandatory          => 0,

        },
        ExpectedResults => {
            ServerError  => undef,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField Checkbox Empty Mandatory',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Checkbox},
            Value              => '',
            Mandatory          => 1,
        },
        ExpectedResults => {
            ServerError  => 1,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField Dropdown',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
            Value              => 1,
            Mandatory          => 0,
        },
        ExpectedResults => {
            ServerError  => undef,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField Dropdown Empty',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
            Value              => 0,
            Mandatory          => 0,

        },
        ExpectedResults => {
            ServerError  => undef,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField Dropdown Empty Mandatory',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
            Value              => '',
            Mandatory          => 1,
        },
        ExpectedResults => {
            ServerError  => 1,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField Dropdown Wrong Value',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
            Value              => 3,
            Mandatory          => 1,
        },
        ExpectedResults => {
            ServerError  => 1,
            ErrorMessage => 'The field content is invalid',
        },
    },
    {
        Name   => 'DynamicField Multiselect',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value              => 1,
            Mandatory          => 0,
        },
        ExpectedResults => '',
    },
    {
        Name   => 'DynamicField Multiselect Empty',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value              => 0,
            Mandatory          => 0,

        },
        ExpectedResults => '',
    },
    {
        Name   => 'DynamicField Multiselect Empty Mandatory',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value              => '',
            Mandatory          => 1,
        },
        ExpectedResults => '',
    },
    {
        Name   => 'DynamicField DateTime',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{DateTime},
            Value              => '2013-08-21 13:46:00',
            Mandatory          => 0,
        },
        ExpectedResults => {
            ServerError  => undef,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField DateTime empty',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{DateTime},
            Value              => '',
            Mandatory          => 0,
        },
        ExpectedResults => {
            ServerError  => undef,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField DateTime Empty Mandatory',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{DateTime},
            Value              => '',
            Mandatory          => 1,
        },
        ExpectedResults => {
            ServerError  => 1,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField DateTime Wrong Format',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{DateTime},
            Value              => '2013/08/21 13:46:00',
            Mandatory          => 1,
        },
        ExpectedResults => {
            ServerError  => 1,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField DateTime Wrong Date',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{DateTime},
            Value              => '2013-31-21 13:46:00',
            Mandatory          => 1,
        },
        ExpectedResults => {
            ServerError  => 1,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField Date',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Date},
            Value              => '2013-08-21 13:46:00',
            Mandatory          => 0,
        },
        ExpectedResults => {
            ServerError  => undef,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField Date empty',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Date},
            Value              => '',
            Mandatory          => 0,
        },
        ExpectedResults => {
            ServerError  => undef,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField Date Empty Mandatory',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Date},
            Value              => '',
            Mandatory          => 1,
        },
        ExpectedResults => {
            ServerError  => 1,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField Date Wrong Format',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Date},
            Value              => '2013/08/21 13:46:00',
            Mandatory          => 1,
        },
        ExpectedResults => {
            ServerError  => 1,
            ErrorMessage => undef,
        },
    },
    {
        Name   => 'DynamicField Date Wrong Date',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Date},
            Value              => '2013-31-21 13:46:00',
            Mandatory          => 1,
        },
        ExpectedResults => {
            ServerError  => 1,
            ErrorMessage => undef,
        },
    },

);

my $DFBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

# execute tests
for my $Test (@Tests) {

    # call IPhoneFieldValueValidate
    my $Result = $DFBackendObject->IPhoneFieldValueValidate( %{ $Test->{Config} } );

    if ( IsHashRefWithData( $Test->{ExpectedResults} ) ) {
        $Self->IsDeeply(
            $Result,
            $Test->{ExpectedResults},
            "$Test->{Name} IPhoneFieldValueValidate() :"
        );
    }
    else {
        $Self->Is(
            $Result,
            undef,
            "$Test->{Name} IPhoneFieldValueValidate() :"
        );
    }
}

# we don't need any cleanup
1;
