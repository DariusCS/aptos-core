// Copyright (c) Aptos
// SPDX-License-Identifier: Apache-2.0

use aptos_types::transaction::{
    ArgumentABI, ScriptABI, ScriptFunctionABI, TransactionScriptABI, TypeArgumentABI,
};
use heck::CamelCase;
use move_deps::move_core_types::language_storage::TypeTag;
use serde_reflection::{ContainerFormat, Format, Named, VariantFormat};
use std::collections::{BTreeMap, BTreeSet};

/// Useful error message.
pub(crate) fn type_not_allowed(type_tag: &TypeTag) -> ! {
    panic!(
        "Transaction scripts cannot take arguments of type {}.",
        type_tag
    );
}

/// Clean up doc comments extracter by the Move prover.
pub(crate) fn prepare_doc_string(doc: &str) -> String {
    doc.replace("\n ", "\n").trim().to_string()
}

fn quote_type_as_format(type_tag: &TypeTag) -> Format {
    use TypeTag::*;
    match type_tag {
        Bool => Format::Bool,
        U8 => Format::U8,
        U64 => Format::U64,
        U128 => Format::U128,
        Address => Format::TypeName("AccountAddress".into()),
        Vector(type_tag) => match type_tag.as_ref() {
            U8 => Format::Bytes,
            Vector(type_tag) => {
                if type_tag.as_ref() == &U8 {
                    Format::Seq(Box::new(Format::Bytes))
                } else {
                    type_not_allowed(type_tag)
                }
            }
            Bool => Format::Seq(Box::new(Format::Bool)),
            U64 => Format::Seq(Box::new(Format::U64)),
            U128 => Format::Seq(Box::new(Format::U128)),
            Address => Format::Seq(Box::new(Format::TypeName("AccountAddress".into()))),
            _ => type_not_allowed(type_tag),
        },
        Struct(_) | Signer => type_not_allowed(type_tag),
    }
}

fn quote_type_parameter_as_field(ty_arg: &TypeArgumentABI) -> Named<Format> {
    Named {
        name: ty_arg.name().to_string(),
        value: Format::TypeName("TypeTag".into()),
    }
}

fn quote_parameter_as_field(arg: &ArgumentABI) -> Named<Format> {
    Named {
        name: arg.name().to_string(),
        value: quote_type_as_format(arg.type_tag()),
    }
}

pub(crate) fn make_abi_enum_container(abis: &[ScriptABI]) -> ContainerFormat {
    let mut variants = BTreeMap::new();
    for (index, abi) in abis.iter().enumerate() {
        let mut fields = Vec::new();
        for ty_arg in abi.ty_args() {
            fields.push(quote_type_parameter_as_field(ty_arg));
        }
        for arg in abi.args() {
            fields.push(quote_parameter_as_field(arg));
        }

        let name = match abi {
            ScriptABI::ScriptFunction(sf) => {
                format!(
                    "{}{}",
                    sf.module_name().name().to_string().to_camel_case(),
                    abi.name().to_camel_case()
                )
            }
            _ => abi.name().to_camel_case(),
        };

        variants.insert(
            index as u32,
            Named {
                name,
                value: VariantFormat::Struct(fields),
            },
        );
    }
    ContainerFormat::Enum(variants)
}

pub(crate) fn mangle_type(type_tag: &TypeTag) -> String {
    use TypeTag::*;
    match type_tag {
        Bool => "bool".into(),
        U8 => "u8".into(),
        U64 => "u64".into(),
        U128 => "u128".into(),
        Address => "address".into(),
        Vector(type_tag) => match type_tag.as_ref() {
            U8 => "u8vector".into(),
            Vector(type_tag) => {
                if type_tag.as_ref() == &U8 {
                    "vecbytes".into()
                } else {
                    type_not_allowed(type_tag)
                }
            }
            _ => format!("vec{}", mangle_type(type_tag)),
        },
        Struct(_) | Signer => type_not_allowed(type_tag),
    }
}

pub(crate) fn get_external_definitions(aptos_types: &str) -> serde_generate::ExternalDefinitions {
    let definitions = vec![(
        aptos_types,
        vec!["AccountAddress", "TypeTag", "Script", "TransactionArgument"],
    )];
    definitions
        .into_iter()
        .map(|(module, defs)| {
            (
                module.to_string(),
                defs.into_iter().map(String::from).collect(),
            )
        })
        .collect()
}

pub(crate) fn get_required_helper_types(abis: &[ScriptABI]) -> BTreeSet<&TypeTag> {
    let mut required_types = BTreeSet::new();
    for abi in abis {
        for arg in abi.args() {
            let type_tag = arg.type_tag();
            required_types.insert(type_tag);
        }
    }
    required_types
}

pub(crate) fn filter_transaction_scripts(abis: &[ScriptABI]) -> Vec<ScriptABI> {
    abis.iter()
        .cloned()
        .filter(|abi| abi.is_transaction_script_abi())
        .collect()
}

pub(crate) fn transaction_script_abis(abis: &[ScriptABI]) -> Vec<TransactionScriptABI> {
    abis.iter()
        .cloned()
        .filter_map(|abi| match abi {
            ScriptABI::TransactionScript(abi) => Some(abi),
            ScriptABI::ScriptFunction(_) => None,
        })
        .collect::<Vec<_>>()
}

pub(crate) fn script_function_abis(abis: &[ScriptABI]) -> Vec<ScriptFunctionABI> {
    abis.iter()
        .cloned()
        .filter_map(|abi| match abi {
            ScriptABI::ScriptFunction(abi) => Some(abi),
            ScriptABI::TransactionScript(_) => None,
        })
        .collect::<Vec<_>>()
}
