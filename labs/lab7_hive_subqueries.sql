-- ============================================================================
-- Lab 7: Hive Subqueries, Views, and Multi-Table Queries
-- ============================================================================
-- Aim: To practice subqueries (IN, EXISTS, correlated), CREATE VIEW, and
--      complex multi-table queries using a movie database schema with tables:
--      ACTOR, MOVIE_CAST, MOVIE, RATING, and REVIEWER.
--
-- Prerequisites:
--   - HiveServer2 running and beeline connected
--
-- Procedure: Execute each step sequentially in Hive CLI or Beeline.
-- ============================================================================

-- --- Step 1: Use or create a database ---
CREATE DATABASE IF NOT EXISTS lab7_db;
USE lab7_db;

-- --- Step 2: Drop tables if they already exist ---
DROP TABLE IF EXISTS ACTOR;
DROP TABLE IF EXISTS MOVIE_CAST;
DROP TABLE IF EXISTS MOVIE;
DROP TABLE IF EXISTS RATING;
DROP TABLE IF EXISTS REVIEWER;
DROP VIEW IF EXISTS MOVIE_SUMMARY;

-- --- Step 3: Create ACTOR table ---
CREATE TABLE ACTOR (
    actor_id    INT,
    actor_name  STRING,
    gender      STRING,
    birth_year  INT
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

-- --- Step 4: Create MOVIE table ---
CREATE TABLE MOVIE (
    movie_id    INT,
    movie_name  STRING,
    release_year INT,
    genre       STRING,
    director    STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

-- --- Step 5: Create MOVIE_CAST table (linking actors to movies) ---
CREATE TABLE MOVIE_CAST (
    movie_id    INT,
    actor_id    INT,
    role_name   STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

-- --- Step 6: Create REVIEWER table ---
CREATE TABLE REVIEWER (
    reviewer_id     INT,
    reviewer_name   STRING,
    platform        STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

-- --- Step 7: Create RATING table ---
CREATE TABLE RATING (
    rating_id   INT,
    movie_id    INT,
    reviewer_id INT,
    rating      DOUBLE,
    review_date STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

-- --- Step 8: Insert data into ACTOR ---
INSERT INTO TABLE ACTOR VALUES (1, 'Shah Rukh Khan', 'M', 1965);
INSERT INTO TABLE ACTOR VALUES (2, 'Deepika Padukone', 'F', 1986);
INSERT INTO TABLE ACTOR VALUES (3, 'Aamir Khan', 'M', 1965);
INSERT INTO TABLE ACTOR VALUES (4, 'Priyanka Chopra', 'F', 1982);
INSERT INTO TABLE ACTOR VALUES (5, 'Ranbir Kapoor', 'M', 1982);

-- --- Step 9: Insert data into MOVIE ---
INSERT INTO TABLE MOVIE VALUES (101, 'Chennai Express', 2013, 'Action', 'Rohit Shetty');
INSERT INTO TABLE MOVIE VALUES (102, 'Padmaavat', 2018, 'Drama', 'Sanjay Leela Bhansali');
INSERT INTO TABLE MOVIE VALUES (103, '3 Idiots', 2009, 'Comedy', 'Rajkumar Hirani');
INSERT INTO TABLE MOVIE VALUES (104, 'Bajirao Mastani', 2015, 'Drama', 'Sanjay Leela Bhansali');
INSERT INTO TABLE MOVIE VALUES (105, 'Yeh Jawaani Hai Deewani', 2013, 'Romance', 'Ayan Mukerji');

-- --- Step 10: Insert data into MOVIE_CAST ---
INSERT INTO TABLE MOVIE_CAST VALUES (101, 1, 'Rahul');
INSERT INTO TABLE MOVIE_CAST VALUES (101, 2, 'Meenamma');
INSERT INTO TABLE MOVIE_CAST VALUES (102, 2, 'Padmavati');
INSERT INTO TABLE MOVIE_CAST VALUES (102, 5, 'Rawal Ratan Singh');
INSERT INTO TABLE MOVIE_CAST VALUES (103, 3, 'Rancho');
INSERT INTO TABLE MOVIE_CAST VALUES (104, 2, 'Kashibai');
INSERT INTO TABLE MOVIE_CAST VALUES (104, 4, 'Mastani');
INSERT INTO TABLE MOVIE_CAST VALUES (105, 5, 'Bunny');
INSERT INTO TABLE MOVIE_CAST VALUES (105, 2, 'Naina');

-- --- Step 11: Insert data into REVIEWER ---
INSERT INTO TABLE REVIEWER VALUES (1, 'Raj', 'IMDb');
INSERT INTO TABLE REVIEWER VALUES (2, 'Simran', 'BookMyShow');
INSERT INTO TABLE REVIEWER VALUES (3, 'Vikram', 'IMDb');
INSERT INTO TABLE REVIEWER VALUES (4, 'Anjali', 'Rotten Tomatoes');

-- --- Step 12: Insert data into RATING ---
INSERT INTO TABLE RATING VALUES (1, 101, 1, 7.5, '2013-08-10');
INSERT INTO TABLE RATING VALUES (2, 101, 2, 8.0, '2013-08-12');
INSERT INTO TABLE RATING VALUES (3, 102, 1, 8.2, '2018-01-30');
INSERT INTO TABLE RATING VALUES (4, 102, 3, 7.8, '2018-02-01');
INSERT INTO TABLE RATING VALUES (5, 103, 1, 9.5, '2009-12-28');
INSERT INTO TABLE RATING VALUES (6, 103, 2, 9.2, '2009-12-30');
INSERT INTO TABLE RATING VALUES (7, 103, 4, 9.0, '2010-01-02');
INSERT INTO TABLE RATING VALUES (8, 104, 3, 8.5, '2015-12-20');
INSERT INTO TABLE RATING VALUES (9, 105, 1, 8.0, '2013-06-05');
INSERT INTO TABLE RATING VALUES (10, 105, 4, 7.5, '2013-06-10');

-- --- Verify all tables ---
SELECT * FROM ACTOR;
SELECT * FROM MOVIE;
SELECT * FROM MOVIE_CAST;
SELECT * FROM REVIEWER;
SELECT * FROM RATING;

-- =========================================================================
-- SUBQUERY QUERIES
-- =========================================================================

-- --- Query 1: Movies with above average rating ---
SELECT movie_name
FROM MOVIE
WHERE movie_id IN (
    SELECT movie_id
    FROM RATING
    GROUP BY movie_id
    HAVING AVG(rating) > (SELECT AVG(rating) FROM RATING)
);

-- --- Query 2: Actors who acted in more than one movie ---
SELECT actor_name
FROM ACTOR
WHERE actor_id IN (
    SELECT actor_id
    FROM MOVIE_CAST
    GROUP BY actor_id
    HAVING COUNT(movie_id) > 1
);

-- --- Query 3: Highest rated movie ---
SELECT m.movie_name, r.avg_rating
FROM MOVIE m
INNER JOIN (
    SELECT movie_id, ROUND(AVG(rating), 2) AS avg_rating
    FROM RATING
    GROUP BY movie_id
) r ON m.movie_id = r.movie_id
ORDER BY r.avg_rating DESC
LIMIT 1;

-- --- Query 4: Movies reviewed by all reviewers of IMDb platform ---
SELECT movie_name
FROM MOVIE
WHERE movie_id NOT IN (
    SELECT movie_id
    FROM RATING
    WHERE reviewer_id IN (
        SELECT reviewer_id FROM REVIEWER WHERE platform = 'IMDb'
    )
);

-- --- Query 5: Correlated subquery - actors in highly rated movies (avg > 8.0) ---
SELECT a.actor_name
FROM ACTOR a
WHERE EXISTS (
    SELECT 1
    FROM MOVIE_CAST mc
    INNER JOIN (
        SELECT movie_id
        FROM RATING
        GROUP BY movie_id
        HAVING AVG(rating) > 8.0
    ) high_rated ON mc.movie_id = high_rated.movie_id
    WHERE mc.actor_id = a.actor_id
);

-- --- Query 6: Directors whose movies have average rating above 7.5 ---
SELECT director
FROM MOVIE
WHERE movie_id IN (
    SELECT movie_id
    FROM RATING
    GROUP BY movie_id
    HAVING AVG(rating) > 7.5
);

-- --- Query 7: Movies with more than 2 reviews ---
SELECT m.movie_name, COUNT(r.rating_id) AS review_count
FROM MOVIE m
INNER JOIN RATING r ON m.movie_id = r.movie_id
GROUP BY m.movie_name
HAVING COUNT(r.rating_id) > 2;

-- --- Query 8: Average rating per genre ---
SELECT m.genre, ROUND(AVG(r.rating), 2) AS avg_rating
FROM MOVIE m
INNER JOIN RATING r ON m.movie_id = r.movie_id
GROUP BY m.genre
ORDER BY avg_rating DESC;

-- --- Query 9: Reviewer who rated the most movies ---
SELECT reviewer_name, platform, COUNT(*) AS ratings_given
FROM REVIEWER rv
INNER JOIN RATING r ON rv.reviewer_id = r.reviewer_id
GROUP BY reviewer_name, platform
ORDER BY ratings_given DESC
LIMIT 1;

-- --- Query 10: Actors with their movie ratings ---
SELECT a.actor_name, m.movie_name, r.rating
FROM ACTOR a
INNER JOIN MOVIE_CAST mc ON a.actor_id = mc.actor_id
INNER JOIN MOVIE m ON mc.movie_id = m.movie_id
INNER JOIN RATING r ON m.movie_id = r.movie_id
ORDER BY r.rating DESC;

-- =========================================================================
-- CREATE VIEW
-- =========================================================================

-- --- Query 11: Create a VIEW for movie summary ---
CREATE VIEW MOVIE_SUMMARY AS
SELECT
    m.movie_id,
    m.movie_name,
    m.genre,
    m.director,
    COUNT(DISTINCT mc.actor_id) AS num_actors,
    COUNT(DISTINCT r.rating_id) AS num_reviews,
    ROUND(AVG(r.rating), 2) AS avg_rating
FROM MOVIE m
LEFT JOIN MOVIE_CAST mc ON m.movie_id = mc.movie_id
LEFT JOIN RATING r ON m.movie_id = r.movie_id
GROUP BY m.movie_id, m.movie_name, m.genre, m.director;

-- --- Query 12: Query the VIEW ---
SELECT * FROM MOVIE_SUMMARY ORDER BY avg_rating DESC;

-- ============================================================================
-- End of Lab 7
-- ============================================================================
