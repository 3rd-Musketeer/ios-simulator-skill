# Contributing

Thanks for helping improve ios-simulator-skill.

## Development setup

1. macOS with Xcode CLI tools and Node.js ≥ 18
2. Clone the repo
3. Run `scripts/check-prereqs.sh`
4. Optional: `npm i -g agent-browser && agent-browser install` for visual verify

## Making changes

1. Fork and create a branch from `main`
2. Edit `SKILL.md`, `references/`, or `examples/skill-test-app/` as needed
3. If you change trigger behavior, update `evals/triggers.json`
4. Run the smoke test:

```bash
cd examples/skill-test-app && ./verify-e2e.sh
```

5. Open a pull request using the PR template

## Skill guidelines

- Keep `SKILL.md` under 500 lines; move detail to `references/`
- Use third-person `description` in frontmatter with clear trigger terms
- Document gotchas you hit during manual testing

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By participating, you agree to uphold it.
