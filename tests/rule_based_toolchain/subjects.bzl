# Copyright 2024 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Test subjects for cc_toolchain_info providers."""

load("@rules_testing//lib:truth.bzl", "subjects")
load(
    "//cc/toolchains:cc_toolchain_info.bzl",
    "ActionConfigInfo",
    "ActionConfigSetInfo",
    "ActionTypeInfo",
    "ActionTypeSetInfo",
    "AddArgsInfo",
    "ArgsInfo",
    "FeatureConstraintInfo",
    "FeatureInfo",
    "FeatureSetInfo",
    "MutuallyExclusiveCategoryInfo",
    "ToolInfo",
)
load(":generate_factory.bzl", "ProviderDepset", "ProviderSequence", "generate_factory")

visibility("private")

# buildifier: disable=name-conventions
_ActionTypeFactory = generate_factory(
    ActionTypeInfo,
    "ActionTypeInfo",
    dict(
        name = subjects.str,
    ),
)

# buildifier: disable=name-conventions
_ActionTypeSetFactory = generate_factory(
    ActionTypeSetInfo,
    "ActionTypeInfo",
    dict(
        actions = ProviderDepset(_ActionTypeFactory),
    ),
)

# buildifier: disable=name-conventions
_MutuallyExclusiveCategoryFactory = generate_factory(
    MutuallyExclusiveCategoryInfo,
    "MutuallyExclusiveCategoryInfo",
    dict(name = subjects.str),
)

_FEATURE_FLAGS = dict(
    name = subjects.str,
    enabled = subjects.bool,
    flag_sets = None,
    implies = None,
    requires_any_of = None,
    provides = ProviderSequence(_MutuallyExclusiveCategoryFactory),
    known = subjects.bool,
    overrides = None,
)

# Break the dependency loop.
# buildifier: disable=name-conventions
_FakeFeatureFactory = generate_factory(
    FeatureInfo,
    "FeatureInfo",
    _FEATURE_FLAGS,
)

# buildifier: disable=name-conventions
_FeatureSetFactory = generate_factory(
    FeatureSetInfo,
    "FeatureSetInfo",
    dict(features = _FakeFeatureFactory),
)

# buildifier: disable=name-conventions
_FeatureConstraintFactory = generate_factory(
    FeatureConstraintInfo,
    "FeatureConstraintInfo",
    dict(
        all_of = ProviderDepset(_FakeFeatureFactory),
        none_of = ProviderDepset(_FakeFeatureFactory),
    ),
)

# buildifier: disable=name-conventions
_AddArgsFactory = generate_factory(
    AddArgsInfo,
    "AddArgsInfo",
    dict(
        args = subjects.collection,
        files = subjects.depset_file,
    ),
)

# buildifier: disable=name-conventions
_ArgsFactory = generate_factory(
    ArgsInfo,
    "ArgsInfo",
    dict(
        actions = ProviderDepset(_ActionTypeFactory),
        args = ProviderSequence(_AddArgsFactory),
        env = subjects.dict,
        files = subjects.depset_file,
        requires_any_of = ProviderSequence(_FeatureConstraintFactory),
    ),
)

# buildifier: disable=name-conventions
_FeatureFactory = generate_factory(
    FeatureInfo,
    "FeatureInfo",
    _FEATURE_FLAGS | dict(
        implies = ProviderDepset(_FakeFeatureFactory),
        requires_any_of = ProviderSequence(_FeatureSetFactory),
        overrides = _FakeFeatureFactory,
    ),
)

# buildifier: disable=name-conventions
_ToolFactory = generate_factory(
    ToolInfo,
    "ToolInfo",
    dict(
        exe = subjects.file,
        runifles = subjects.depset_file,
        requires_any_of = ProviderSequence(_FeatureConstraintFactory),
    ),
)

# buildifier: disable=name-conventions
_ActionConfigFactory = generate_factory(
    ActionConfigInfo,
    "ActionConfigInfo",
    dict(
        action = _ActionTypeFactory,
        enabled = subjects.bool,
        tools = ProviderSequence(_ToolFactory),
        flag_sets = ProviderSequence(_ArgsFactory),
        implies = ProviderDepset(_FeatureFactory),
        files = subjects.depset_file,
    ),
)

def _action_config_set_factory_impl(value, *, meta):
    # We can't use the usual strategy of "inline the labels" since all labels
    # are the same.
    transformed = {}
    for ac in value.action_configs.to_list():
        key = ac.action.label
        if key in transformed:
            meta.add_failure("Action declared twice in action config", key)
        transformed[key] = _ActionConfigFactory.factory(
            value = ac,
            meta = meta.derive(".get({})".format(key)),
        )
    return transformed

# buildifier: disable=name-conventions
_ActionConfigSetFactory = struct(
    type = ActionConfigSetInfo,
    name = "ActionConfigSetInfo",
    factory = _action_config_set_factory_impl,
)

FACTORIES = [
    _ActionTypeFactory,
    _ActionTypeSetFactory,
    _AddArgsFactory,
    _ArgsFactory,
    _MutuallyExclusiveCategoryFactory,
    _FeatureFactory,
    _FeatureConstraintFactory,
    _FeatureSetFactory,
    _ToolFactory,
    _ActionConfigSetFactory,
]
