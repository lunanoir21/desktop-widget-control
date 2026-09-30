# Security

Desktop Widget Control runs as your user, reads `/proc`, `/sys` and MPRIS, and talks to the network only for the weather widget and the place picker (Open-Meteo, through `curl`). It has no daemon and no network listener.

If you find a problem that could be abused (for example a widget option that ends up in a shell command), please report it privately through GitHub's *Report a vulnerability* button on this repository rather than in a public issue.
