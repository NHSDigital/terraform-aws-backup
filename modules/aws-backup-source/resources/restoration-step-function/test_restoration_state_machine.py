import re
from pathlib import Path


def load_tf_text():
    tf_file = Path(__file__).parent.parent.parent / "restore_state_machine.tf"
    return tf_file.read_text()


def test_core_states_present():
    text = load_tf_text()
    expected = [
        "CopyRecoveryPoint",
        "WaitForCopy",
        "PollCopyStatus",
        "CopyCompletionChoice",
        "PrepareRestoreTargets",
        "RestoreTargetsMap",
        "Success"
    ]
    missing = [s for s in expected if f'"{s}"' not in text]
    assert not missing, f"Missing expected state names in definition: {missing}"


def test_map_iterator_structure():
    text = load_tf_text()
    for child in ["RestoreChoice", "RestoreS3", "RestoreRDS"]:
        assert f'"{child}"' in text, f"Iterator missing child state {child}"


if __name__ == "__main__":
    # Run tests manually if invoked directly
    test_core_states_present()
    test_map_iterator_structure()
    print("All restoration state machine tests passed.")
