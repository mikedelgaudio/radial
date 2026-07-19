import Foundation
import XCTest

func run(_ name: String, _ body: () throws -> Void) {
    do { try body() } catch { XCTestRegistry.record("\(name) threw \(error)", #file, #line) }
}

MainActor.assumeIsolated {
    // Task 2 — CoreSpecsCodableTests
    let coreSpecs = CoreSpecsCodableTests()
    run("CoreSpecs.test_kit_links", coreSpecs.test_kit_links)
    run("CoreSpecs.test_colorSpec_roundTrips_named_and_rgba", coreSpecs.test_colorSpec_roundTrips_named_and_rgba)
    run("CoreSpecs.test_iconSpec_roundTrips_all_cases", coreSpecs.test_iconSpec_roundTrips_all_cases)
    run("CoreSpecs.test_hotKeySpec_default_is_cmd_opt_shift_leftBracket", coreSpecs.test_hotKeySpec_default_is_cmd_opt_shift_leftBracket)
    run("CoreSpecs.test_actionType_and_availability_are_string_codable", coreSpecs.test_actionType_and_availability_are_string_codable)

    // Task 3 & 4 — ConfigCodableTests
    let configCodable = ConfigCodableTests()
    run("ConfigCodable.test_action_roundTrips", configCodable.test_action_roundTrips)
    run("ConfigCodable.test_action_defaults_when_optional_fields_missing", configCodable.test_action_defaults_when_optional_fields_missing)
    run("ConfigCodable.test_mode_normalizes_to_eight_slots", configCodable.test_mode_normalizes_to_eight_slots)
    run("ConfigCodable.test_config_roundTrips", configCodable.test_config_roundTrips)
    run("ConfigCodable.test_mode_defaults_contextual_false_when_missing", configCodable.test_mode_defaults_contextual_false_when_missing)

    // Task 5 — DefaultConfigTests
    let defaultConfig = DefaultConfigTests()
    run("DefaultConfig.test_default_has_expected_modes", defaultConfig.test_default_has_expected_modes)
    run("DefaultConfig.test_apps_mode_seeds_known_apps_in_order", defaultConfig.test_apps_mode_seeds_known_apps_in_order)
    run("DefaultConfig.test_default_config_is_codable_roundtrip", defaultConfig.test_default_config_is_codable_roundtrip)

    // Task 6 — ConfigStoreTests (@MainActor)
    let configStore = ConfigStoreTests()
    run("ConfigStore.test_first_load_writes_defaults", configStore.test_first_load_writes_defaults)
    run("ConfigStore.test_save_then_load_roundtrips", configStore.test_save_then_load_roundtrips)
    run("ConfigStore.test_corrupt_file_is_backed_up_and_defaults_loaded", configStore.test_corrupt_file_is_backed_up_and_defaults_loaded)
    run("ConfigStore.test_restoreDefaults_overwrites", configStore.test_restoreDefaults_overwrites)

    // Task 7 — RingGeometryTests
    let ringGeometry = RingGeometryTests()
    run("RingGeometry.test_slot0_is_at_top", ringGeometry.test_slot0_is_at_top)
    run("RingGeometry.test_indices_go_clockwise", ringGeometry.test_indices_go_clockwise)
    run("RingGeometry.test_angle_step_is_uniform", ringGeometry.test_angle_step_is_uniform)

    // Task 8 — RingViewModelTests (@MainActor)
    let ringVM = RingViewModelTests()
    run("RingVM.test_left_wraps_outer_selection", ringVM.test_left_wraps_outer_selection)
    run("RingVM.test_right_advances_and_wraps", ringVM.test_right_advances_and_wraps)
    run("RingVM.test_focus_moves_outer_inner_center_and_back", ringVM.test_focus_moves_outer_inner_center_and_back)
    run("RingVM.test_activate_filled_outer_slot_returns_runAction", ringVM.test_activate_filled_outer_slot_returns_runAction)
    run("RingVM.test_activate_empty_outer_slot_returns_none", ringVM.test_activate_empty_outer_slot_returns_none)
    run("RingVM.test_activate_inner_mode_switches_mode", ringVM.test_activate_inner_mode_switches_mode)
    run("RingVM.test_activate_inner_settings_item_returns_openSettings", ringVM.test_activate_inner_settings_item_returns_openSettings)
    run("RingVM.test_activate_inner_addMode_item_returns_addMode", ringVM.test_activate_inner_addMode_item_returns_addMode)
    run("RingVM.test_activate_center_opens_settings", ringVM.test_activate_center_opens_settings)

    // Task 9 — ActionRunnerTests
    let actionRunner = ActionRunnerTests()
    run("ActionRunner.test_application_plan_uses_resolved_url_and_arguments", actionRunner.test_application_plan_uses_resolved_url_and_arguments)
    run("ActionRunner.test_application_plan_fails_when_unresolved", actionRunner.test_application_plan_fails_when_unresolved)
    run("ActionRunner.test_script_plan_wraps_in_sh_lc", actionRunner.test_script_plan_wraps_in_sh_lc)
    run("ActionRunner.test_script_plan_fails_on_empty_command", actionRunner.test_script_plan_fails_on_empty_command)
    run("ActionRunner.test_url_plan", actionRunner.test_url_plan)
    run("ActionRunner.test_folder_plan", actionRunner.test_folder_plan)

    // Task 10 — HotKeyCarbonTests
    let hotKey = HotKeyCarbonTests()
    run("HotKey.test_modifier_mapping_combines_flags", hotKey.test_modifier_mapping_combines_flags)
    run("HotKey.test_control_flag_maps", hotKey.test_control_flag_maps)
    run("HotKey.test_unknown_modifier_ignored", hotKey.test_unknown_modifier_ignored)
    run("HotKey.test_display_string", hotKey.test_display_string)
}

print("ControlRingTests — checks: \(XCTestRegistry.checks), failures: \(XCTestRegistry.failures.count)")
for f in XCTestRegistry.failures { print("  FAIL \(f)") }
if XCTestRegistry.failures.isEmpty { print("ALL TESTS PASSED") }
exit(XCTestRegistry.failures.isEmpty ? 0 : 1)
