--Item A
CREATE TABLE "users" (
  "id" SERIAL PRIMARY KEY,
  "username" VARCHAR(25) UNIQUE
);
ALTER TABLE
  "users"
ADD
  CONSTRAINT "is_empty_username" CHECK(
    LENGTH(
      TRIM("username")
    )> 0
  );
ALTER TABLE
  "users" ALTER COLUMN "username"
SET
  NOT NULL;
CREATE INDEX "username_index" ON "users"("username");
--Item b
CREATE TABLE "topics" (
  "id" SERIAL PRIMARY KEY,
  "topics_name" VARCHAR(30) UNIQUE,
  "description" VARCHAR(500)
);
ALTER TABLE
  "topics"
ADD
  CONSTRAINT "is_empty_topic_name" CHECK(
    LENGTH(
      TRIM("topics_name")
    )> 0
  );
ALTER TABLE
  "topics" ALTER COLUMN "topics_name"
SET
  NOT NULL;
CREATE INDEX "topics_name_index" ON "topics"("topics_name");
-- Item c
CREATE TABLE "posts" (
  "id" SERIAL PRIMARY KEY,
  "title" VARCHAR(100) NOT NULL,
  "url" VARCHAR,
  "content" TEXT,
  "user_id" INTEGER REFERENCES "users" ON DELETE
  SET
    NULL,
    "topics_id" INTEGER REFERENCES "topics" ON DELETE CASCADE
);
ALTER TABLE
  "posts"
ADD
  CONSTRAINT "is_empty_title" CHECK(
    LENGTH(
      TRIM("title")
    )> 0
  );
ALTER TABLE
  "posts"
ADD
  CONSTRAINT "check_content_url" CHECK(
    (
      LENGTH(
        TRIM("content")
      )> 0
      AND LENGTH(
        TRIM("url")
      )= 0
    )
    OR (
      LENGTH(
        TRIM("content")
      )= 0
      AND LENGTH(
        TRIM("url")
      )> 0
    )
  );
CREATE INDEX "id_topics_id_index" ON "posts"("id", "topics_id");
CREATE INDEX "id_user_id_index" ON "posts"("id", "user_id");
CREATE INDEX "url_index" ON "posts"("url");
--Item d
CREATE TABLE "comments" (
  "id" SERIAL PRIMARY KEY,
  "content" TEXT NOT NULL,
  "post_id" INTEGER REFERENCES "posts" ON DELETE CASCADE,
  "user_id" INTEGER REFERENCES "users" ON DELETE
  SET
    NULL,
    "comments_id" INTEGER REFERENCES "comments" ON DELETE CASCADE
);
ALTER TABLE
  "comments"
ADD
  CONSTRAINT "is_empty_content" CHECK(
    LENGTH(
      TRIM("content")
    )> 0
  );
CREATE INDEX "id_comments_index" ON "comments"("id");
CREATE INDEX "id_comments_id_index" ON "comments"("comments_id", "id");
CREATE INDEX "id_comments_user_id_index" ON "comments"("user_id", "id");
--Item e
CREATE TABLE "votes" (
  "user_id" INTEGER REFERENCES "users" ON DELETE
  SET
    NULL,
    "post_id" INTEGER REFERENCES "posts" ON DELETE CASCADE,
    "upvotes" SMALLINT,
    "downvotes" SMALLINT
);
ALTER TABLE
  "votes"
ADD
  CONSTRAINT "unique_vote" UNIQUE("post_id", "user_id");
CREATE INDEX "upvote_index" ON "votes"("post_id", "upvotes");
CREATE INDEX "downvote_index" ON "votes"("post_id", "downvotes");

--Part III - Migrate the provided data
--Migrate data to users table
INSERT INTO "users"("username")
SELECT
  DISTINCT "bad_posts"."username"
FROM
  "bad_posts"
  LEFT JOIN "users" ON "bad_posts"."username" = "users"."username"
WHERE
  "users"."id" IS NULL;
INSERT INTO "users"("username")
SELECT
  DISTINCT "bad_comments"."username"
FROM
  "bad_comments"
  LEFT JOIN "users" ON "bad_comments"."username" = "users"."username"
WHERE
  "users"."id" IS NULL;
WITH t1 AS(
  SELECT
    DISTINCT REGEXP_SPLIT_TO_TABLE("bad_posts"."downvotes", ',') regex
  FROM
    "bad_posts"
) INSERT INTO "users"("username")
SELECT
  "regex"
FROM
  "t1"
  LEFT JOIN "users" ON "t1"."regex" = "users"."username"
WHERE
  "users"."id" IS NULL;
WITH t2 AS(
  SELECT
    DISTINCT REGEXP_SPLIT_TO_TABLE("bad_posts"."upvotes", ',') regex
  FROM
    "bad_posts"
) INSERT INTO "users"("username")
SELECT
  "regex"
FROM
  "t2"
  LEFT JOIN "users" ON "t2"."regex" = "users"."username"
WHERE
  "users"."id" IS NULL;
--Migrate data to topics table
INSERT INTO "topics"("topics_name")
SELECT
  DISTINCT "topic"
FROM
  "bad_posts";
--Migrate data to posts table
ALTER TABLE
  "posts"
ADD
  COLUMN "username" VARCHAR;
ALTER TABLE
  "posts"
ADD
  COLUMN "topicsname" VARCHAR;
ALTER TABLE
  "posts"
ADD
  COLUMN "temp_id" INTEGER;
ALTER TABLE
  "posts"
ADD
  COLUMN "temp_upvote" TEXT;
ALTER TABLE
  "posts"
ADD
  COLUMN "temp_downvote" TEXT;
INSERT INTO "posts"(
  "title", "url", "content", "username",
  "topicsname", "temp_id", "temp_upvote",
  "temp_downvote"
)
SELECT
  LEFT("bad_posts"."title", 100),
  "bad_posts"."url",
  "bad_posts"."text_content",
  "username",
  "topic",
  "id",
  "upvotes",
  "downvotes"
FROM
  "bad_posts";
UPDATE
  "posts"
SET
  "user_id" =(
    SELECT
      "users"."id"
    FROM
      "users"
    WHERE
      "posts"."username" = "users"."username"
  );
UPDATE
  "posts"
SET
  "topics_id" =(
    SELECT
      "topics"."id"
    FROM
      "topics"
    WHERE
      "posts"."topicsname" = "topics"."topics_name"
  );
ALTER TABLE
  "posts"
DROP
  COLUMN "username",
DROP
  COLUMN "topicsname";
--Migrate data to comments table
ALTER TABLE
  "comments"
ADD
  COLUMN "username" VARCHAR;
ALTER TABLE
  "comments"
ADD
  COLUMN "temp_id" INTEGER;
INSERT INTO "comments"("content", "post_id", "username")
SELECT
  "b"."text_content",
  "posts"."id",
  "b"."username"
FROM
  "bad_comments" AS "b"
  JOIN "posts" ON "b"."id" = "posts"."temp_id";
UPDATE
  "comments"
SET
  "user_id" =(
    SELECT
      "users"."id"
    FROM
      "users"
    WHERE
      "comments"."username" = "users"."username"
  );
ALTER TABLE
  "comments"
DROP
  COLUMN "username";
ALTER TABLE
  "posts"
DROP
  COLUMN "temp_id";
--Migrate data to votes table
ALTER TABLE
  "votes"
ADD
  COLUMN "temp_upvote" VARCHAR;
ALTER TABLE
  "votes"
ADD
  COLUMN "temp_downvote" VARCHAR;
INSERT INTO "votes"("post_id", "temp_upvote")
SELECT
  "posts"."id",
  REGEXP_SPLIT_TO_TABLE("posts"."temp_upvote", ',')
FROM
  "posts";
INSERT INTO "votes"("post_id", "temp_downvote")
SELECT
  "posts"."id",
  REGEXP_SPLIT_TO_TABLE("posts"."temp_downvote", ',')
FROM
  "posts";
UPDATE
  "votes"
SET
  "user_id" =(
    SELECT
      "users"."id"
    FROM
      "users"
    WHERE
      "votes"."temp_upvote" = "users"."username"
  )
WHERE
  "votes"."temp_upvote" IS NOT NULL;
UPDATE
  "votes"
SET
  "user_id" =(
    SELECT
      "users"."id"
    FROM
      "users"
    WHERE
      "votes"."temp_downvote" = "users"."username"
  )
WHERE
  "votes"."temp_downvote" IS NOT NULL;
UPDATE
  "votes"
SET
  "upvotes" = 1
WHERE
  "votes"."temp_upvote" IS NOT NULL;
UPDATE
  "votes"
SET 
  "downvotes" =-1
WHERE
  "votes"."temp_downvote" IS NOT NULL;
ALTER TABLE
  "posts"
DROP
  COLUMN "temp_upvote",
DROP
  COLUMN "temp_downvote";
ALTER TABLE
  "votes"
DROP
  COLUMN "temp_upvote",
DROP
  COLUMN "temp_downvote";
