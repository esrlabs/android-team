# Team Blog

This blog is powered by [Hugo](https://gohugo.io/), a static html site generator.

Best viewn at https://esrlabs.github.io/android-team/

## Contributing

As this is the blog of the ESR Labs Android Team, only team members can contribute.

Run `hugo server` to view your changes locally at http://localhost:1313/

### Creating a new post

A new post can be created with

`hugo new posts/<name-of-post>.md`

Once you are done with writing, make sure to

- review your changes locally with `hugo server`, and
- find a reviewer from the team before publishing your changes.

### Modifying our Team Collage

Our collage consits of android icons and photos of team members:

![](./static/team.png)


#### Android Logos

Logos representing the different android version were taken from wikipedia:

https://commons.wikimedia.org/wiki/File:Android_12_Developer_Preview_logo.svg

see "Other Versions" for a complete list of Android Logos per Version

#### Team Member Photos

Photos of new team members should go into

`static/team-photos`

Afterwards the script `./create_collage.sh` can be invoked to

- downsize the photo (for privacy reasons)
- update the collage at `./static/team.png`


