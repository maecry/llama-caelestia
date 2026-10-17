// StatusNotifierItem for the caelestia bar: robot icon, hover shows start/stop.
use std::process::Command;
use std::sync::LazyLock;
use ksni::{Icon, ToolTip, Tray, TrayMethods, menu::*};

// shortcut: repo path is baked in at build time, rebuild if the project moves
const CTL: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/llama-ctl.sh");
const WEB_UI: &str = "http://127.0.0.1:8000";

fn ctl(cmd: &str) -> bool {
    Command::new(CTL)
        .arg(cmd)
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

#[derive(Default)]
struct Llama {
    running: bool,
}

impl Tray for Llama {
    fn id(&self) -> String {
        "llama-server".into()
    }

    fn title(&self) -> String {
        "llama.cpp".into()
    }

    fn icon_pixmap(&self) -> Vec<Icon> {
        static ICON: LazyLock<Icon> = LazyLock::new(|| {
            let mut reader = png::Decoder::new(std::io::Cursor::new(&include_bytes!("../robot.png")[..]))
                .read_info()
                .expect("valid png");
            assert_eq!(reader.info().color_type, png::ColorType::Rgba, "robot.png must be RGBA");
            let (width, height) = reader.info().size();
            let mut data = vec![0; reader.output_buffer_size().expect("valid png")];
            reader.next_frame(&mut data).expect("valid png");
            for pixel in data.chunks_exact_mut(4) {
                pixel.rotate_right(1) // rgba -> argb
            }
            Icon {
                width: width as i32,
                height: height as i32,
                data,
            }
        });
        vec![ICON.clone()]
    }

    fn tool_tip(&self) -> ToolTip {
        ToolTip {
            title: "llama.cpp".into(),
            description: if self.running { "Server running" } else { "Server stopped" }.into(),
            ..Default::default()
        }
    }

    fn activate(&mut self, _x: i32, _y: i32) {
        ctl("toggle");
        self.running = !self.running;
    }

    fn menu_about_to_show(&mut self) {
        self.running = ctl("status");
    }

    fn menu(&self) -> Vec<MenuItem<Self>> {
        vec![
            StandardItem {
                label: if self.running { "llama.cpp: running" } else { "llama.cpp: stopped" }.into(),
                enabled: false,
                ..Default::default()
            }
            .into(),
            MenuItem::Separator,
            StandardItem {
                label: if self.running { "Stop server" } else { "Start server" }.into(),
                activate: Box::new(|this: &mut Self| {
                    ctl(if this.running { "stop" } else { "start" });
                    this.running = !this.running;
                }),
                ..Default::default()
            }
            .into(),
            StandardItem {
                label: "Open web UI".into(),
                enabled: self.running,
                activate: Box::new(|_| {
                    let _ = Command::new("xdg-open").arg(WEB_UI).spawn();
                }),
                ..Default::default()
            }
            .into(),
        ]
    }
}

#[tokio::main(flavor = "current_thread")]
async fn main() {
    Llama {
        running: ctl("status"),
    }
    .spawn()
    .await
    .expect("no StatusNotifierWatcher - is the caelestia shell running?");
    std::future::pending::<()>().await
}
