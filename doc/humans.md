# humans.txt

Sometimes we want to publicly celebrate someone who's leaving GOV.UK. The convention for this is to temporarily update [gov.uk/humans.txt](https://www.gov.uk/humans.txt) with some words about their time on the programme.

We should be judicious about who we choose to celebrate this way, so it remains something special. This should be when someone has been working on the programme for over 5 years, or has had an exceptional (positive) impact.

Anyone can write these words, but we should try to use a consistent style. Look back through the [history](https://github.com/alphagov/govuk-helm-charts/blob/main/charts/app-config/humans.txt) and [earlier history on static](https://github.com/alphagov/static/blob/32b5743557ecc83e84908b55aab8027f2d9bf051/public/humans.txt) of `humans.txt` to see what others have written before you, and then compose your own text.

## How to update the page

1. Append some nice words to [`charts/app-config/humans.txt`](../charts/app-config/humans.txt).

2. Raise a PR and get a technical and a content review.

3. Deploy the PR to production and wait for the cache to clear.

4. Raise a PR to remove the content after a few days.
