use eyre::eyre;
use krunner::{Match, RunnerExt};
use rink_core::{one_line, simple_context};

#[derive(Debug, Copy, Clone, Eq, PartialEq, krunner::Action)]
enum Action {
    #[action(id = "copy", title = "Copy result to clipboard", icon = "edit-copy")]
    Copy,
}

struct Runner;

impl krunner::Runner for Runner {
    type Action = Action;

    type Err = eyre::Error;

    fn matches(&mut self, query: String) -> Result<Vec<krunner::Match<Self::Action>>, Self::Err> {
        let mut ctx = simple_context()
            .map_err(|e| eyre::eyre!("Failed to obtain simple rink context: {e}"))?;
        let Ok(rink_res) = one_line(&mut ctx, &query) else {
            return Ok(vec![]);
        };

        let (value, desc) = rink_res
            .split_once(" (")
            .map(|(title, desc)| {
                (
                    title.to_string(),
                    Some(desc.trim_end_matches(')').to_string()),
                )
            })
            .unwrap_or((rink_res.clone(), None));

        let m = Match {
            id: value.clone(),
            title: value.clone(),
            subtitle: desc,
            icon: "accessories-calculator".to_string().into(),
            ty: krunner::MatchType::ExactMatch,
            relevance: 1.,
            multiline: false,
            actions: vec![Action::Copy],
            ..Default::default()
        };

        Ok(vec![m])
    }

    fn run(&mut self, match_id: String, action: Option<Self::Action>) -> Result<(), Self::Err> {
        if let Some(Action::Copy) = action {
            cli_clipboard::set_contents(match_id)
                .map_err(|e| eyre!("Failed to set clipboard contents: {e}"))?;
        }

        Ok(())
    }
}

fn main() {
    let r = Runner;
    r.start(env!("DBUS_SERVICE"), env!("DBUS_PATH")).unwrap();
}
