use crate::vocab;

pub struct KernelVocab {
    strings: Vec<String>
}

impl KernelVocab {
    pub fn get_string(&self, index: usize) -> Option<&String> {
        self.strings.get(index)
    }

    pub fn get_strings(&self) -> &Vec<String> {
        &self.strings
    }
}

fn fill_default_kcalls(strings: &mut Vec<String>) {
    // 0
    strings.push("Load".to_string());
    strings.push("UnLoad".to_string());
    strings.push("ScriptID".to_string());
    strings.push("DisposeScript".to_string());
    strings.push("Clone".to_string());
    strings.push("DisposeClone".to_string());
    strings.push("IsObject".to_string());
    strings.push("RespondsTo".to_string());
    strings.push("DrawPic".to_string());
    strings.push("Show".to_string());
    // 10
    strings.push("PicNotValid".to_string());
    strings.push("Animate".to_string());
    strings.push("SetNowSeen".to_string());
    strings.push("NumLoops".to_string());
    strings.push("NumCels".to_string());
    strings.push("CelWide".to_string());
    strings.push("CelHigh".to_string());
    strings.push("DrawCel".to_string());
    strings.push("AddToPic".to_string());
    strings.push("NewWindow".to_string());
    // 20
    strings.push("GetPort".to_string());
    strings.push("SetPort".to_string());
    strings.push("DisposeWindow".to_string());
    strings.push("DrawControl".to_string());
    strings.push("HiliteControl".to_string());
    strings.push("EditControl".to_string());
    strings.push("TextSize".to_string());
    strings.push("Display".to_string());
    strings.push("GetEvent".to_string());
    strings.push("GlobalToLocal".to_string());
    // 30
    strings.push("LocalToGlobal".to_string());
    strings.push("MapKeyToDir".to_string());
    strings.push("DrawMenuBar".to_string());
    strings.push("MenuSelect".to_string());
    strings.push("AddMenu".to_string());
    strings.push("DrawStatus".to_string());
    strings.push("<dummy36>".to_string());
    strings.push("<dummy37>".to_string());
    strings.push("<dummy38>".to_string());
    strings.push("HaveMouse".to_string());
    // 40
    strings.push("SetCursor".to_string());
    strings.push("SaveGame".to_string());
    strings.push("RestoreGame".to_string());
    strings.push("RestartGame".to_string());
    strings.push("GameIsRestarting".to_string());
    strings.push("DoSound".to_string());
    strings.push("NewList".to_string());
    strings.push("DisposeList".to_string());
    strings.push("NewNode".to_string());
    strings.push("FirstNode".to_string());
    // 50
    strings.push("LastNode".to_string());
    strings.push("EmptyList".to_string());
    strings.push("NextNode".to_string());
    strings.push("PrevNode".to_string());
    strings.push("NodeValue".to_string());
    strings.push("AddAfter".to_string());
    strings.push("AddToFront".to_string());
    strings.push("AddToEnd".to_string());
    strings.push("FindKey".to_string());
    strings.push("DeleteKey".to_string());
    // 60
    strings.push("Random".to_string());
    strings.push("Abs".to_string());
    strings.push("Sqrt".to_string());
    strings.push("GetAngle".to_string());
    strings.push("GetDistance".to_string());
    strings.push("Wait".to_string());
    strings.push("GetTime".to_string());
    strings.push("StrEnd".to_string());
    strings.push("StrCat".to_string());
    strings.push("StrCmp".to_string());
    // 70
    strings.push("StrLen".to_string());
    strings.push("StrCpy".to_string());
    strings.push("Format".to_string());
    strings.push("GetFarText".to_string());
    strings.push("ReadNumber".to_string());
    strings.push("BaseSetter".to_string());
    strings.push("DirLoop".to_string());
    strings.push("CantBeHere".to_string());
    strings.push("OnControl".to_string());
    strings.push("InitBresen".to_string());
    // 80
    strings.push("DoBresen".to_string());
    strings.push("Platform".to_string());
    strings.push("SetJump".to_string());
    strings.push("SetDebug".to_string());
    strings.push("InspectObj".to_string());
    strings.push("ShowSends".to_string());
    strings.push("<dummy86>".to_string());
    strings.push("ShowFree".to_string());
    strings.push("MemoryInfo".to_string());
    strings.push("StackUsage".to_string());
    // 90
    strings.push("Profiler".to_string());
    strings.push("GetMenu".to_string());
    strings.push("SetMenu".to_string());
    strings.push("GetSaveFiles".to_string());
    strings.push("GetCWD".to_string());
    strings.push("CheckFreeSpace".to_string());
    strings.push("ValidPath".to_string());
    strings.push("CoordPri".to_string());
    strings.push("StrAt".to_string());
    strings.push("DeviceInfo".to_string());
    // 100
    strings.push("GetSaveDir".to_string());
    strings.push("CheckSaveGame".to_string());
    strings.push("ShakeScreen".to_string());
    strings.push("FlushResources".to_string());
    strings.push("SinMult".to_string());
    strings.push("CosMult".to_string());
    strings.push("SinDiv".to_string());
    strings.push("CosDiv".to_string());
    strings.push("Graph".to_string());
    strings.push("Joystick".to_string());
    // 110
    strings.push("ShiftScreen".to_string());
    strings.push("Palette".to_string());
    strings.push("MemorySegment".to_string());
    strings.push("PalVary".to_string());
    strings.push("Memory".to_string());
    strings.push("ListOps".to_string());
    strings.push("FileIO".to_string());
    strings.push("DoAudio".to_string());
    strings.push("DoSync".to_string());
    strings.push("AvoidPath".to_string());
    // 120
    strings.push("Sort".to_string());
    strings.push("ATan".to_string());
    strings.push("Lock".to_string());
    strings.push("RemapColors".to_string());
    strings.push("Message".to_string());
    strings.push("IsItSkip".to_string());
    strings.push("MergePoly".to_string());
    strings.push("ResCheck".to_string());
    strings.push("AssertPalette".to_string());
    strings.push("TextColors".to_string());
    // 130
    strings.push("TextFonts".to_string());
    strings.push("Record".to_string());
    strings.push("PlayBack".to_string());
    strings.push("ShowMovie".to_string());
    strings.push("SetVideoMode".to_string());
    strings.push("SetQuitStr".to_string());
    strings.push("DbugStr".to_string());
}

pub fn load_kernel_vocab(extract_path: &str) -> KernelVocab {
    let mut strings = Vec::<String>::new();
    if let Ok(vocab_999_data) = std::fs::read(format!("{}/vocab.999", extract_path)) {
        match vocab::Vocab999::new(&vocab_999_data) {
            Ok(v) => {
                for s in v.get_strings() {
                    strings.push(s.clone());
                }
            },
            Err(_) => {
                match vocab::Vocab997::new(&vocab_999_data) {
                    Ok(v) => {
                        for s in v.get_strings() {
                            strings.push(s.clone());
                        }
                    },
                    Err(_) => { }
                }
            }
        }
    }

    if strings.is_empty() {
        fill_default_kcalls(&mut strings);
    }
    KernelVocab{ strings }
}
