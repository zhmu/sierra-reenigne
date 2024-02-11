use pest::Parser;
use pest_derive::Parser;
use anyhow::{anyhow, Result};

use pest::iterators::Pairs;

#[derive(Parser)]
#[grammar = "scitool.pest"]
struct SciParser;

#[derive(Debug)]
pub struct SciProperty {
    pub id: String,
    pub value: u16
}

#[derive(Debug)]
pub struct SciMethod {
    pub name: String,
    pub code: Vec<String>
}

#[derive(Debug)]
pub struct SciItem {
    pub id: String,
    pub super_class: String,
    pub properties: Vec<SciProperty>,
    pub methods: Vec<SciMethod>
}

#[derive(Debug)]
pub struct SciDispatch {
    pub id: u16,
    pub code: Vec<String>
}

#[derive(Debug)]
pub struct SciScript {
    pub variables: Vec<u16>,
    pub items: Vec<SciItem>,
    pub dispatches: Vec<SciDispatch>
}

fn parse_variables(pairs: Pairs<Rule>) -> Result<Vec<u16>> {
    let mut vars = Vec::<u16>::new();
    for local in pairs {
        let mut local = local.into_inner();
        let num = local.next().unwrap();
        let value = local.next().unwrap();

        let num = num.as_str().parse::<u16>().expect("not a number");
        let value = value.as_str().parse::<u16>().expect("not a number");

        let current = vars.len() as u16;
        if num != current { return Err(anyhow!(format!("local index {} specified, expected {}", num, current))) };
        vars.push(value);
    }
    Ok(vars)
}

fn parse_properties(pairs: Pairs<Rule>) -> Result<Vec<SciProperty>> {
    let mut props = Vec::<SciProperty>::new();
    for prop in pairs {
        let mut p = prop.into_inner();
        let id = p.next().unwrap().as_str().to_string();
        let value = p.next().unwrap().as_str();
        let value = value.parse::<u16>().expect("not a number");
        props.push(SciProperty{ id, value })
    }
    Ok(props)
}

fn parse_code(mut items: Pairs<Rule>) -> Vec<String> {
    // XXX We should leave splitting up to the parser instead
    items
        .next().unwrap().into_inner()
        .next().unwrap().as_str()
        .split("\n")
        .map(|s| s.to_string())
        .collect::<Vec<_>>()
}

fn parse_items(items: Pairs<Rule>) -> Result<Vec<SciItem>> {
    let mut result = Vec::<SciItem>::new();
    for item in items {
        let mut item = item.into_inner();
        let id = item.next().unwrap().as_str().to_string();
        let super_class = item.next().unwrap().as_str().to_string();

        let mut object_props = item.next().unwrap().into_inner();
        let props = object_props.next().unwrap().into_inner();
        let properties = parse_properties(props)?;

        let mut methods = Vec::<SciMethod>::new();
        let method = object_props.next().unwrap().into_inner();
        for m in method {
            let mut m = m.into_inner();
            let name = m.next().unwrap().as_str().to_string();
            // XXX We should leave splitting up to the parser instead
            //let code = m.next().unwrap().into_inner().next().unwrap().as_str().split("\n").map(|s| s.to_string()).collect::<Vec<_>>();
            let code = parse_code(m);
            methods.push(SciMethod{ name, code })
        }

        result.push(SciItem{ id, super_class, properties, methods })
    }
    Ok(result)
}

fn parse_dispatches(items: Pairs<Rule>) -> Result<Vec<SciDispatch>> {
    let mut result = Vec::<SciDispatch>::new();
    for m in items {
        let mut m = m.into_inner();
        let id = m.next().unwrap().as_str().to_string();
        let code = parse_code(m);

        let id = id.as_str().parse::<u16>().expect("not a number");
        result.push(SciDispatch{ id, code })
    }
    Ok(result)
}

impl SciScript {
    pub fn parse_sciscript(s: &str) -> Result<SciScript> {
        let mut p = SciParser::parse(Rule::script, &s)?;

        let mut locals: Option<Vec<u16>> = None;
        let mut items: Option<Vec<SciItem>> = None;
        let mut dispatches: Option<Vec<SciDispatch>> = None;
        let p = p.next().unwrap();
        for p in p.into_inner() {
            match p.as_rule() {
                Rule::locals => {
                    locals = Some(parse_variables(p.into_inner())?);
                },
                Rule::items => {
                    items = Some(parse_items(p.into_inner())?);
                },
                Rule::dispatches => {
                    dispatches = Some(parse_dispatches(p.into_inner())?);
                },
                Rule::EOI => { },
                _ => unreachable!()
            }
        }

        Ok(SciScript{ variables: locals.unwrap(), items: items.unwrap(), dispatches: dispatches.unwrap() })
    }
}
