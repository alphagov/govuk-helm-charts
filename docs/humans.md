# humans.txt

Sometimes we want to publicly celebrate someone who's leaving GOV.UK. The convention for this is to temporarily update [gov.uk/humans.txt](https://www.gov.uk/humans.txt) with some words about their time on the programme.

We should be judicious about who we choose to celebrate this way, so it remains something special. This should be when someone has been working on the programme for over 5 years, or has had an exceptional (positive) impact.

Anyone can write these words, but we should try to use a consistent style. Look back through the [history](./charts/app-config/humans) of `humans.txt` to see what others have written before you, and then compose your own text.

## How to add a new humans.txt

1. Create a new file in the [`charts/app-config/humans`](../charts/app-config/humans). The filename should be `name-lastname-YYYY-MM-DD.txt`, where YYYY-MM-DD is the leaving date of the person in question. You don't need to include the base humans.txt information, your file will be appended to it.

2. Raise a PR and get a technical and a content review.

3. Deploy the PR to production

4. Your file will be appended to /humans.txt on the day in the file title, and removed the day after. You don't need to raise a PR to remove it (and indeed you shouldn't, beacuse it will be used for `/heroes.txt` - see below)

## /heroes.txt

[/heroes.txt](https://www.gov.uk/heroes.txt) will show a random file from the humans directory. It's updated with a new random file every time the router helm charts are written.
