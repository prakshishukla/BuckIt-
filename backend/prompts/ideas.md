Suggest 6 fresh bucket-list items for a group of friends in $city this $season.
The list is called "$list_name". $mood_line
Don't repeat anything already on it: $existing
Make them specific, real places or events, fun, safe, legal and doable. Mix effort levels. Each one must be provable with a single photo.

Respond with strict JSON only:
{"ideas": [{"title": string (max 6 words), "description": string (one sentence), "location": string,
            "category": one of [$categories], "commitment": one of [low, medium, high]}]}
