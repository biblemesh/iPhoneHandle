# --
# iPhoneFieldValueGet.t - iPhoneFieldValueGet backend tests
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
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

use Kernel::System::VariableCheck qw(:all);

my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

$ConfigObject->Set(
    Key   => 'TimeZoneUser',
    Value => 1
);

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
            DynamicFieldConfig     => $DynamicFieldConfigs{Text},
            DynamicField_TextField => 'Priority',
        },
        ExpectedResult => 'Priority',
    },
    {
        Name   => 'DynamicField Text Area',
        Config => {
            DynamicFieldConfig         => $DynamicFieldConfigs{TextArea},
            DynamicField_TextAreaField => 'Priority',
        },
        ExpectedResult => 'Priority',
    },
    {
        Name   => 'DynamicField Checkbox',
        Config => {
            DynamicFieldConfig         => $DynamicFieldConfigs{Checkbox},
            DynamicField_CheckboxField => 1,
        },
        ExpectedResult => 1,
    },
    {
        Name   => 'DynamicField Dropdown',
        Config => {
            DynamicFieldConfig         => $DynamicFieldConfigs{Dropdown},
            DynamicField_DropdownField => 2,
        },
        ExpectedResult => 2,
    },
    {
        Name   => 'DynamicField Multiselect',
        Config => {
            DynamicFieldConfig            => $DynamicFieldConfigs{Multiselect},
            DynamicField_MultiselectField => 2,
        },
        ExpectedResult => '',
    },
    {
        Name   => 'DynamicField DateTime Normal',
        Config => {
            DynamicFieldConfig         => $DynamicFieldConfigs{DateTime},
            DynamicField_DateTimeField => '2013-08-21 13:46:00',
        },
        ExpectedResult => '2013-08-21 13:46:00',
    },
    {
        Name   => 'DynamicField DateTime TimeZone -6',
        Config => {
            DynamicFieldConfig         => $DynamicFieldConfigs{DateTime},
            DynamicField_DateTimeField => '2013-08-21 13:46:00',
            UserTimeZone               => -6,
        },
        ExpectedResult => '2013-08-21 19:46:00',
    },
    {
        Name   => 'DynamicField DateTime TimeZone +11',
        Config => {
            DynamicFieldConfig         => $DynamicFieldConfigs{DateTime},
            DynamicField_DateTimeField => '2013-08-21 9:46:00',
            UserTimeZone               => 11,
        },
        ExpectedResult => '2013-08-20 22:46:00',
    },
    {
        Name   => 'DynamicField Date Normal',
        Config => {
            DynamicFieldConfig     => $DynamicFieldConfigs{Date},
            DynamicField_DateField => '2013-08-21 13:46',
        },
        ExpectedResult => '2013-08-21 00:00:00',
    },
    {
        Name   => 'DynamicField Date TimeZone -6',
        Config => {
            DynamicFieldConfig     => $DynamicFieldConfigs{Date},
            DynamicField_DateField => '2013-08-21 13:46',
            UserTimeZone           => -6,
        },
        ExpectedResult => '2013-08-21 00:00:00',
    },
    {
        Name   => 'DynamicField Date TimeZone +11',
        Config => {
            DynamicFieldConfig     => $DynamicFieldConfigs{Date},
            DynamicField_DateField => '2013-08-21 13:46',
            UserTimeZone           => 11,
        },
        ExpectedResult => '2013-08-21 00:00:00',
    },
);

my $DFBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

# execute tests
for my $Test (@Tests) {

    # call IPhoneFieldValueGet
    my $Value = $DFBackendObject->IPhoneFieldValueGet( %{ $Test->{Config} } );

    if ( $Test->{ExpectedResult} ) {
        $Self->Is(
            $Value,
            $Test->{ExpectedResult},
            "$Test->{Name} IPhoneFieldValueGet() :"
        );
    }
    else {
        $Self->Is(
            $Value,
            undef,
            "$Test->{Name} IPhoneFieldValueGet() :"
        );
    }
}

# we don't need any cleanup
1;
