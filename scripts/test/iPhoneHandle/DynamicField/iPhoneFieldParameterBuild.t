# --
# iPhoneFieldParameterBuild.t - iPhoneFieldParameterBuild backend tests
# Copyright (C) 2001-2013 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;
use vars (qw($Self));

use Kernel::System::DynamicField::Backend;
use Kernel::System::UnitTest::Helper;
use Kernel::System::VariableCheck qw(:all);

my $HelperObject = Kernel::System::UnitTest::Helper->new(
    %$Self,
    UnitTestObject => $Self,
);

my $DFBackendObject = Kernel::System::DynamicField::Backend->new( %{$Self} );

my $EnLanguageObject = Kernel::Language->new(
    %{$Self},
    UserLanguage => 'en',
);
my $EsLanguageObject = Kernel::Language->new(
    %{$Self},
    UserLanguage => 'es',
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
        Name   => 'DynamicField Text EN',
        Config => {
            DynamicFieldConfig   => $DynamicFieldConfigs{Text},
            Value                => 'Priority',
            Mandatory            => 1,
            UseDefaultValue      => 0,
            OverridePossibleNone => undef,
            LanguageObject       => $EnLanguageObject
        },
        ExpectedResults => {
            Name      => 'DynamicField_TextField',
            Title     => 'Owner',
            Datatype  => 'Text',
            Viewtype  => 'Input',
            Min       => 1,
            Max       => 200,
            Mandatory => 1,
            Default   => 'Priority',
        },
    },
    {
        Name   => 'DynamicField Text ES',
        Config => {
            DynamicFieldConfig   => $DynamicFieldConfigs{Text},
            Value                => 'Priority',
            Mandatory            => 1,
            UseDefaultValue      => 0,
            OverridePossibleNone => undef,
            LanguageObject       => $EsLanguageObject
        },
        ExpectedResults => {
            Name      => 'DynamicField_TextField',
            Title     => 'Propietario',
            Datatype  => 'Text',
            Viewtype  => 'Input',
            Min       => 1,
            Max       => 200,
            Mandatory => 1,
            Default   => 'Priority',
        },
    },
    {
        Name   => 'DynamicField Text Area EN',
        Config => {
            DynamicFieldConfig   => $DynamicFieldConfigs{TextArea},
            Value                => 'Priority',
            Mandatory            => 0,
            UseDefaultValue      => 0,
            OverridePossibleNone => undef,
            LanguageObject       => $EnLanguageObject
        },
        ExpectedResults => {
            Name      => 'DynamicField_TextAreaField',
            Title     => 'Owner',
            Datatype  => 'Text',
            Viewtype  => 'TextArea',
            Min       => 1,
            Max       => 20000,
            Mandatory => 0,
            Default   => 'Priority',
        },
    },
    {
        Name   => 'DynamicField Text Area ES',
        Config => {
            DynamicFieldConfig   => $DynamicFieldConfigs{TextArea},
            Value                => 'Priority',
            Mandatory            => 0,
            UseDefaultValue      => 0,
            OverridePossibleNone => undef,
            LanguageObject       => $EsLanguageObject
        },
        ExpectedResults => {
            Name      => 'DynamicField_TextAreaField',
            Title     => 'Propietario',
            Datatype  => 'Text',
            Viewtype  => 'TextArea',
            Min       => 1,
            Max       => 20000,
            Mandatory => 0,
            Default   => 'Priority',
        },
    },
    {
        Name   => 'DynamicField Checkbox EN',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Checkbox},
            Value                => 1,
            Mandatory            => 0,
            UseDefaultValue      => 0,
            OverridePossibleNone => undef,
            LanguageObject       => $EnLanguageObject
        },
        ExpectedResults => {
            Name      => 'DynamicField_CheckboxField',
            Title     => 'Owner',
            Datatype  => 'Text',
            Viewtype  => 'Picker',
            Mandatory => 0,
            Options   => {
                0 => 'Unchecked',
                1 => 'Checked',
            },
            Default   => 1,
        },
    },
    {
        Name   => 'DynamicField Checkbox ES',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Checkbox},
            Value                => 0,
            Mandatory            => 1,
            UseDefaultValue      => 1,
            OverridePossibleNone => undef,
            LanguageObject       => $EsLanguageObject
        },
        ExpectedResults => {
            Name      => 'DynamicField_CheckboxField',
            Title     => 'Propietario',
            Datatype  => 'Text',
            Viewtype  => 'Picker',
            Mandatory => 1,
            Options   => {
                0 => 'Unchecked',
                1 => 'Checked',
            },
            Default   => 0,
        },
    },
    {
        Name   => 'DynamicField Dropdown EN',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
            Value                => 2,
            Mandatory            => 1,
            UseDefaultValue      => 1,
            OverridePossibleNone => undef,
            LanguageObject       => $EnLanguageObject
        },
        ExpectedResults => {
            Name      => 'DynamicField_DropdownField',
            Title     => 'Owner',
            Datatype  => 'Text',
            Viewtype  => 'Picker',
            Mandatory => 1,
            Options   => {
                1 => 'Priority',
                2 => 'State',
            },
            Default   => 2,
        },
    },
    {
        Name   => 'DynamicField Dropdown ES',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
            Value                => 2,
            Mandatory            => 1,
            UseDefaultValue      => 1,
            OverridePossibleNone => 1,
            LanguageObject       => $EsLanguageObject
        },
        ExpectedResults => {
            Name      => 'DynamicField_DropdownField',
            Title     => 'Propietario',
            Datatype  => 'Text',
            Viewtype  => 'Picker',
            Mandatory => 1,
            Options   => {
                '' => '-',
                1  => 'Prioridad',
                2  => 'Estado',
            },
            Default   => 2,
        },
    },
    {
        Name   => 'DynamicField Multiselect',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value                => 2,
            Mandatory            => 1,
            UseDefaultValue      => 1,
            OverridePossibleNone => undef,
            LanguageObject       => $EnLanguageObject
        },
        ExpectedResults => '',
    },
    {
        Name   => 'DynamicField DateTime EN',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{DateTime},
            Value                => '2013/08/21 13:46',
            Mandatory            => 1,
            UseDefaultValue      => 1,
            OverridePossibleNone => undef,
            LanguageObject       => $EnLanguageObject
        },
        ExpectedResults => {
            Name => 'DynamicField_DateTimeField',
            Title => 'Owner',
            Datatype => 'DateTime',
            Viewtype => 'Picker',
            Mandatory => 1,
            Default => '2013/08/21 13:46',
        },
    },
    {
        Name   => 'DynamicField DateTime ES',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{DateTime},
            Value                => '2013/08/21 13:46',
            Mandatory            => 1,
            UseDefaultValue      => 1,
            OverridePossibleNone => undef,
            LanguageObject       => $EsLanguageObject
        },
        ExpectedResults => {
            Name => 'DynamicField_DateTimeField',
            Title => 'Propietario',
            Datatype => 'DateTime',
            Viewtype => 'Picker',
            Mandatory => 1,
            Default => '2013/08/21 13:46',
        },
    },
    {
        Name   => 'DynamicField Date EN',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Date},
            Value                => '2013/08/21 13:46',
            Mandatory            => 1,
            UseDefaultValue      => 1,
            OverridePossibleNone => undef,
            LanguageObject       => $EnLanguageObject
        },
        ExpectedResults => {
            Name => 'DynamicField_DateField',
            Title => 'Owner',
            Datatype => 'Date',
            Viewtype => 'Picker',
            Mandatory => 1,
            Default => '2013/08/21 13:46',
        },
    },
    {
        Name   => 'DynamicField Date ES',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Date},
            Value                => '2013/08/21 13:46',
            Mandatory            => 1,
            UseDefaultValue      => 1,
            OverridePossibleNone => undef,
            LanguageObject       => $EsLanguageObject
        },
        ExpectedResults => {
            Name => 'DynamicField_DateField',
            Title => 'Propietario',
            Datatype => 'Date',
            Viewtype => 'Picker',
            Mandatory => 1,
            Default => '2013/08/21 13:46',
        },
    },
);

# execute tests
for my $Test (@Tests) {

    # call IPhoneFieldParameterBuild
    my $FieldDefinition = $DFBackendObject->IPhoneFieldParameterBuild( %{ $Test->{Config} } );

    if ( IsHashRefWithData( $Test->{ExpectedResults} ) ) {
        $Self->IsDeeply(
            $FieldDefinition,
            $Test->{ExpectedResults},
             "$Test->{Name} IPhoneFieldParameterBuild() :"
        );
    }
    else {
        $Self->Is(
            $FieldDefinition,
            undef,
             "$Test->{Name} IPhoneFieldParameterBuild() :"
        );

    }
}

# we don't need any cleanup
1;
