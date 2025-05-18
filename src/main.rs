use eyre::eyre;
use krunner::{Match, RunnerExt};
use rink_core::{
    CURRENCY_FILE, ast::Defs, loader::gnu_units, one_line, parsing::datetime::parse_datefile,
};

#[derive(Debug, Copy, Clone, Eq, PartialEq, krunner::Action)]
enum Action {
    #[action(id = "copy", title = "Copy result to clipboard", icon = "edit-copy")]
    Copy,
}

struct Runner {
    ctx: rink_core::Context,
}

impl Runner {
    pub fn new() -> Self {
        let mut ctx = rink_core::Context::new();

        let units = gnu_units::parse_str(rink_core::DEFAULT_FILE.unwrap());
        let dates = parse_datefile(rink_core::DATES_FILE.unwrap());

        let mut currency_defs = gnu_units::parse_str(CURRENCY_FILE.unwrap()).defs;

        match reqwest::blocking::get("https://rinkcalc.app/data/currency.json") {
            Ok(r) => match r.json::<Defs>() {
                Ok(mut live_defs) => currency_defs.append(&mut live_defs.defs),
                Err(e) => println!("Error parsing currency json: {e}"),
            },
            Err(e) => println!("Failed to get up-do-date currency info: {e}"),
        }

        if let Err(e) = ctx.load(units) {
            println!("Failed to load units into context: {e}");
        }

        if let Err(e) = ctx.load(Defs {
            defs: currency_defs,
        }) {
            println!("Failed to load currencies into context: {e}");
        }

        ctx.load_dates(dates);

        Self { ctx }
    }
}

impl krunner::Runner for Runner {
    type Action = Action;

    type Err = eyre::Error;

    fn matches(&mut self, query: String) -> Result<Vec<krunner::Match<Self::Action>>, Self::Err> {
        let Ok(rink_res) = one_line(&mut self.ctx, &query) else {
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

    fn run(&mut self, match_id: String, _: Option<Self::Action>) -> Result<(), Self::Err> {
        cli_clipboard::set_contents(match_id)
            .map_err(|e| eyre!("Failed to set clipboard contents: {e}"))?;

        Ok(())
    }
}

fn main() {
    let r = Runner::new();
    r.start(env!("DBUS_SERVICE"), env!("DBUS_PATH")).unwrap();
}
