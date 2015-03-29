# enwrite

> What wild heart-histories seemed to lie enwritten<br/>
> Upon those crystalline, celestial spheres!
<p align="right">&mdash;Edgar Allan Poe</p>

Evernote-powered statically-generated blogs and websites.

Very early work-in-progress, more to come soon.

For now it produces output suitable for [http://gohugo.io](Hugo). You
need to have an existing Hugo install. Sample usage (for now you need
to get an Evernote authentication token at
https://sandbox.evernote.com/api/DeveloperToken.action:

    $ export EN_AUTH_TOKEN=xxxxxxxxx
    $ export RUBYLIB=./lib
    $ ./enwrite.rb -h
    Usage: ./enwrite.rb [-n notebook | -e searchexp ] -o outdir
    
        -n, --notebook NOTEBOOK          Process notes from specified notebook.
        -t, --tag TAG                    Process notes that have the specified tag.
        -s, --search SEARCHEXP           Process notes that match specified search expression.
        -o, --output-dir OUTDIR          Base dir of hugo output installation.
        -h, --help                       Shows this help message
    
    $ ./enwrite.rb -n my_notebook -o /my/hugo/blog/
    
    $ ./enwrite.rb -s 'some search expression' -o /my/hugo/blog
