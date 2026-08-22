Upgrading to MakeTaggable 1.0

This release renames the declaration methods and changes how delimiters are escaped.

1. Rename the declarations in your models:

     acts_as_taggable                    ->  make_taggable
     acts_as_taggable_on :skills         ->  make_taggable :skills
     acts_as_ordered_taggable            ->  make_ordered_taggable
     acts_as_ordered_taggable_on :skills ->  make_ordered_taggable :skills
     acts_as_tagger                      ->  make_tagger

   Everything generated per context keeps its name: skill_list, skills,
   skill_counts, top_skills, skills_from, find_related_skills.

2. If you configure a delimiter containing a regular expression
   metacharacter, unescape it. Delimiters are now literal strings:

     MakeTaggable.delimiter = ['\|']  ->  MakeTaggable.delimiter = ["|"]

3. If you rely on `make_taggable` with no arguments adding no contexts,
   note that it now tags on :tags.

4. Requirements are now Ruby 3.2 and Active Record 7.2 or newer.

Note for anyone upgrading past 1.0: a later migration adds a unique index
preventing duplicate unowned taggings. If it fails, your taggings table
already holds duplicates -- docs/database.md has a snippet to clear them.

Install any new migrations:

    rails make_taggable_engine:install:migrations
    rails db:migrate

Full notes: https://github.com/MatthewKennedy/make_taggable/blob/master/CHANGELOG.md
