# --
# Kernel/System/DynamicField/iPhoneFilter/Backend/Multiselect.pm - Delegate for DynamicField Multiselect backend
# Copyright (C) 2001-2012 OTRS AG, http://otrs.org/
# --
# $Id: Multiselect.pm,v 1.1 2012-02-24 21:55:35 cr Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::iPhone::Backend::Multiselect;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::System::DynamicFieldValue;

use vars qw($VERSION);
$VERSION = qw($Revision: 1.1 $) [1];

=head1 NAME

Kernel::System::DynamicField::iPhone::Backend::TextArea

=head1 SYNOPSIS

DynamicFields Multiselect backend delegate for IPhoneHandle

=head1 PUBLIC INTERFACE

This module implements the public interface of L<Kernel::System::DynamicField::iPhone::iPhoneBackend>.
Please look there for a detailed reference of the functions.

=over 4

=item new()

usually, you want to create an instance of this
by using Kernel::System::DynamicField::iPhone::iPhoneBackend->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    for my $Needed (qw(ConfigObject EncodeObject LogObject MainObject DBObject)) {
        die "Got no $Needed!" if !$Param{$Needed};

        $Self->{$Needed} = $Param{$Needed};
    }

    # create additional objects
    $Self->{DynamicFieldValueObject} = Kernel::System::DynamicFieldValue->new( %{$Self} );

    return $Self;
}

sub IsIPhoneCapable {
    my ( $Self, %Param ) = @_;

    return 0;
}

sub EditFieldRender {
    my ( $Self, %Param ) = @_;

    # not supported by iPhone App
    return;
}

sub EditFieldValueGet {
    my ( $Self, %Param ) = @_;

    # not supported by iPhone App
    return;
}

sub EditFieldValueValidate {
    my ( $Self, %Param ) = @_;

    # not supported by iPhone App
    return;
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

$$

=cut
