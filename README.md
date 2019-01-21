_DISCLAIMER: I've never programmed in go._

# About

This project was inspired in bringing autocomplete into emacs extending
`company-terraform` from
https://github.com/rafalcieslak/emacs-company-terraform

Autocompletion in that project is generated by scraping the documentation
page. That is a tedious job to do, error prone and not maintainable.

This project aims to use go plugins in order to provide resources
documentation.

# WIP

The project is a work in progress. Main goal is to return JSON into stdout,
then it could be parsed by external tools for whatever reason you want.

# How it works

Each provider for terraform is a github repository in `terraform-providers`
organization. The script clones each repo, generates a go file per repo, and via
reflection inspect each [`Provider`](https://github.com/hashicorp/terraform/blob/master/helper/schema/provider.go#L25) object. I'm using reflection because for
some reason the [`Schema`](git clone https://github.com/gentunian/terraform-autodoc.git
) field is not accesible outside terraform package.


# Use

[WIP]You may clone the repo and build the image yourself but be aware that it will
pull at least 99 (the actual number as of this commit) repositories from github
and take a few minutes and 4GB of space...


# Limitations

If terraform providers plugins does not specify `Description` field describing
what each resource do, documentation will be scarse.