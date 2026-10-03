# Bastion integration checks

```text
python -m unittest discover -s tests/themes -p test_bastion_registration.py -v
```

Run from the repository root with Python 3.11+ and Lupa 2.8 installed. The
wrapper reads `bastion_registration.json`; it requires no other custom theme.
See [fixture details and evidence limits](README.md).
