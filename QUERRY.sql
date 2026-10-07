use ipl;
select * from matches;
select * from ball_by_ball;
select * from extra_runs;
select * from season;
select * from team;
select * from player;
select * from player_match;


-------------------------  OBJECTIVE QUESTIONS   ------
--  Q1 List the different dtypes of columns in table “ball_by_ball” (using information schema) 
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'ipl' AND TABLE_NAME = 'Ball_by_Ball';



-- Q2 What is the total number of runs scored in 1st season by RCB (bonus: also include the extra runs using the extra runs table)
SELECT
    SUM(b.Runs_Scored) + COALESCE(SUM(e.Extra_Runs),0) AS total_runs_including_extras
FROM ball_by_ball b
JOIN matches m
    ON b.Match_Id = m.Match_Id
LEFT JOIN extra_runs e
    ON b.Match_Id = e.Match_Id
   AND b.Over_Id = e.Over_Id
   AND b.Ball_Id = e.Ball_Id
   AND b.Innings_No = e.Innings_No
WHERE b.Team_Batting = 2
AND m.Season_Id = (
    SELECT MIN(Season_Id)
    FROM matches
);



-- Q3 How many players were more than the age of 25 during season 2014?
SELECT COUNT(DISTINCT pm.Player_Id) AS players_above_25
FROM player_match pm
JOIN matches m
    ON pm.Match_Id = m.Match_Id
JOIN player p
    ON pm.Player_Id = p.Player_Id
JOIN season s
    ON m.Season_Id = s.Season_Id
WHERE s.Season_Year = 2014
AND TIMESTAMPDIFF(YEAR, p.DOB, '2014-01-01') > 25;




-- Q4: How many matches did RCB win in 2013?
SELECT COUNT(*) AS matches_won
FROM matches m
JOIN season s
    ON m.Season_Id = s.Season_Id
WHERE s.Season_Year = 2013
AND m.Match_Winner = (
    SELECT Team_Id
    FROM team
    WHERE Team_Name = 'Royal Challengers Bangalore'
);
  
  
  
  

  
  
  
  
  -- Q5 List the top 10 players according to their strike rate in the last 4 seasons]
  SELECT p.Player_Name,
       SUM(bb.Runs_Scored) AS Total_Runs,
       COUNT(*) AS Balls_Faced,
       ROUND(SUM(bb.Runs_Scored) * 100.0 / COUNT(*), 2) AS Strike_Rate
FROM Ball_by_Ball bb
JOIN Player p ON bb.Striker = p.Player_Id
GROUP BY p.Player_Id, p.Player_Name
HAVING COUNT(*) >= 50
ORDER BY Strike_Rate DESC
LIMIT 10;




-- Q6 What are the average runs scored by each batsman considering all the seasons?
SELECT p.Player_Name,
       ROUND(AVG(t.innings_runs), 2) AS avg_runs
FROM (
    SELECT b.Striker, b.Match_Id, b.Innings_No,
           SUM(b.Runs_Scored) AS innings_runs
    FROM Ball_by_Ball b
    GROUP BY b.Striker, b.Match_Id, b.Innings_No
) t
JOIN Player p ON t.Striker = p.Player_Id
GROUP BY t.Striker
ORDER BY avg_runs DESC;




-- Q7 What are the average wickets taken by each bowler considering all the seasons?

SELECT p.Player_Name,
       ROUND(AVG(t.season_wkts), 2) AS avg_wickets_per_season
FROM (
    SELECT b.Bowler, m.Season_Id, COUNT(*) AS season_wkts
    FROM Wicket_Taken w
    JOIN Ball_by_Ball b
      ON w.Match_Id = b.Match_Id AND w.Over_Id = b.Over_Id
     AND w.Ball_Id = b.Ball_Id AND w.Innings_No = b.Innings_No
    JOIN Matches m ON b.Match_Id = m.Match_Id
    GROUP BY b.Bowler, m.Season_Id
) t
JOIN Player p ON t.Bowler = p.Player_Id
GROUP BY t.Bowler
ORDER BY avg_wickets_per_season DESC;



-- Q8 List all the players who have average runs scored greater than the overall average and who have taken wickets greater than the overall average
WITH batsman_avg AS (
    SELECT Striker,
           AVG(innings_runs) AS avg_runs
    FROM (
        SELECT b.Striker, b.Match_Id, b.Innings_No,
               SUM(b.Runs_Scored) AS innings_runs
        FROM Ball_by_Ball b
        GROUP BY b.Striker, b.Match_Id, b.Innings_No
    ) t
    GROUP BY Striker
),
bowler_avg AS (
    SELECT b.Bowler,
           COUNT(*) * 1.0 / COUNT(DISTINCT m.Season_Id) AS avg_wkts
    FROM Wicket_Taken w
    JOIN Ball_by_Ball b
      ON w.Match_Id = b.Match_Id AND w.Over_Id = b.Over_Id
     AND w.Ball_Id = b.Ball_Id AND w.Innings_No = b.Innings_No
    JOIN Matches m ON b.Match_Id = m.Match_Id
    GROUP BY b.Bowler
)
SELECT p.Player_Name,
       ROUND(ba.avg_runs, 2) AS avg_runs,
       ROUND(bw.avg_wkts, 2) AS avg_wickets
FROM batsman_avg ba
JOIN bowler_avg bw ON ba.Striker = bw.Bowler
JOIN Player p ON p.Player_Id = ba.Striker
WHERE ba.avg_runs > (SELECT AVG(avg_runs) FROM batsman_avg)
  AND bw.avg_wkts > (SELECT AVG(avg_wkts) FROM bowler_avg)
ORDER BY ba.avg_runs DESC;






-- Q9 Create a table rcb_record table that shows the wins and losses of RCB in an individual venue
CREATE TABLE rcb_record AS
SELECT 
    v.Venue_Name,
    SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) AS Wins,
    SUM(CASE WHEN m.Match_Winner != 2 AND m.Match_Winner IS NOT NULL THEN 1 ELSE 0 END) AS Losses,
    SUM(CASE WHEN m.Match_Winner IS NULL THEN 1 ELSE 0 END) AS No_Result,
    COUNT(*) AS Total_Matches
FROM Matches m
JOIN Venue v ON m.Venue_Id = v.Venue_Id
WHERE m.Team_1 = 2 OR m.Team_2 = 2
GROUP BY v.Venue_Id, v.Venue_Name
ORDER BY Wins DESC;
select * from rcb_record;

-- Q10 What is the impact of bowling style on wickets taken?
SELECT bs.Bowling_skill, COUNT(*) AS total_wickets
FROM Wicket_Taken w
JOIN Ball_by_Ball b
  ON w.Match_Id = b.Match_Id AND w.Over_Id = b.Over_Id
 AND w.Ball_Id = b.Ball_Id AND w.Innings_No = b.Innings_No
JOIN Player p ON b.Bowler = p.Player_Id
JOIN Bowling_Style bs ON p.Bowling_skill = bs.Bowling_Id
GROUP BY bs.Bowling_skill
ORDER BY total_wickets DESC;



-- Q11 Write the SQL query to provide a status of whether the performance of the team is better than the previous
-- year's performance on the basis of the number of runs scored by the team in the season and the number of wickets taken 
SELECT
    cur.Team_Name,
    cur.Season_Year,
    cur.total_runs,
    cur.total_wickets,
    CASE
        WHEN prev.total_runs IS NULL THEN 'First Season'
        WHEN cur.total_runs > prev.total_runs
         AND cur.total_wickets > prev.total_wickets
            THEN 'Better'
        WHEN cur.total_runs < prev.total_runs
         AND cur.total_wickets < prev.total_wickets
            THEN 'Worse'
        ELSE 'Mixed'
    END AS Performance_Status
FROM
(
    SELECT
        t.Team_Id,
        t.Team_Name,
        s.Season_Year,
        SUM(b.Runs_Scored) AS total_runs,
        COUNT(w.Player_Out) AS total_wickets
    FROM ball_by_ball b
    JOIN matches m
        ON b.Match_Id = m.Match_Id
    JOIN season s
        ON m.Season_Id = s.Season_Id
    JOIN team t
        ON b.Team_Batting = t.Team_Id
    LEFT JOIN wicket_taken w
        ON b.Match_Id = w.Match_Id
       AND b.Over_Id = w.Over_Id
       AND b.Ball_Id = w.Ball_Id
       AND b.Innings_No = w.Innings_No
    GROUP BY t.Team_Id, t.Team_Name, s.Season_Year
) cur
LEFT JOIN
(
    SELECT
        t.Team_Id,
        t.Team_Name,
        s.Season_Year,
        SUM(b.Runs_Scored) AS total_runs,
        COUNT(w.Player_Out) AS total_wickets
    FROM ball_by_ball b
    JOIN matches m
        ON b.Match_Id = m.Match_Id
    JOIN season s
        ON m.Season_Id = s.Season_Id
    JOIN team t
        ON b.Team_Batting = t.Team_Id
    LEFT JOIN wicket_taken w
        ON b.Match_Id = w.Match_Id
       AND b.Over_Id = w.Over_Id
       AND b.Ball_Id = w.Ball_Id
       AND b.Innings_No = w.Innings_No
    GROUP BY t.Team_Id, t.Team_Name, s.Season_Year
) prev
    ON cur.Team_Id = prev.Team_Id
   AND cur.Season_Year = prev.Season_Year + 1
ORDER BY cur.Team_Name, cur.Season_Year;




-- Q12 Can you derive more KPIs for the team strategy?
SELECT
    t.Team_Name,
    COUNT(*) AS Matches_Played,
    SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Wins,
    ROUND(
        SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) * 100.0 /
        COUNT(*), 2
    ) AS Win_Percentage
FROM team t
JOIN matches m
    ON t.Team_Id IN (m.Team_1, m.Team_2)
GROUP BY t.Team_Id, t.Team_Name
ORDER BY Win_Percentage DESC;

SELECT
    t.Team_Name,
    ROUND(AVG(team_runs),2) AS Avg_Team_Score
FROM
(
    SELECT
        Match_Id,
        Team_Batting,
        SUM(Runs_Scored) AS team_runs
    FROM ball_by_ball
    GROUP BY Match_Id, Team_Batting
) x
JOIN team t
    ON x.Team_Batting = t.Team_Id
GROUP BY t.Team_Name
ORDER BY Avg_Team_Score DESC;

SELECT
    t.Team_Name,
    ROUND(COUNT(w.Player_Out) /
          COUNT(DISTINCT b.Match_Id), 2) AS Avg_Wickets_Per_Match
FROM wicket_taken w
JOIN ball_by_ball b
    ON w.Match_Id=b.Match_Id
   AND w.Over_Id=b.Over_Id
   AND w.Ball_Id=b.Ball_Id
   AND w.Innings_No=b.Innings_No
JOIN team t
    ON b.Team_Bowling=t.Team_Id
GROUP BY t.Team_Name
ORDER BY Avg_Wickets_Per_Match DESC;


SELECT
    t.Team_Name,
    SUM(CASE WHEN b.Runs_Scored IN (4,6) THEN b.Runs_Scored ELSE 0 END) AS Boundary_Runs,
    SUM(b.Runs_Scored) AS Total_Runs,
    ROUND(
        SUM(CASE WHEN b.Runs_Scored IN (4,6) THEN b.Runs_Scored ELSE 0 END)
        *100.0 / SUM(b.Runs_Scored),2
    ) AS Boundary_Percentage
FROM ball_by_ball b
JOIN team t
    ON b.Team_Batting=t.Team_Id
GROUP BY t.Team_Name
ORDER BY Boundary_Percentage DESC;

-- TOSS IMPACT ANALYSIS
SELECT
    t.Team_Name,
    COUNT(*) AS Tosses_Won,
    SUM(CASE WHEN m.Toss_Winner = m.Match_Winner THEN 1 ELSE 0 END) AS Toss_And_Match_Won
FROM matches m
JOIN team t
    ON m.Toss_Winner=t.Team_Id
GROUP BY t.Team_Name;

-- HOME VENUE ADVANTAGE
SELECT
    v.Venue_Name,
    COUNT(*) AS Matches,
    SUM(CASE WHEN Match_Winner = 2 THEN 1 ELSE 0 END) AS RCB_Wins
FROM matches m
JOIN venue v
    ON m.Venue_Id=v.Venue_Id
WHERE Team_1=2 OR Team_2=2
GROUP BY v.Venue_Name;

-- Death Overs Performance (16–20 Overs)
SELECT
    t.Team_Name,
    ROUND(AVG(death_runs),2) AS Avg_Death_Overs_Runs
FROM
(
    SELECT
        Match_Id,
        Team_Batting,
        SUM(Runs_Scored) AS death_runs
    FROM ball_by_ball
    WHERE Over_Id BETWEEN 16 AND 20
    GROUP BY Match_Id, Team_Batting
) x
JOIN team t
    ON x.Team_Batting=t.Team_Id
GROUP BY t.Team_Name
ORDER BY Avg_Death_Overs_Runs DESC;

-- Powerplay Performance (Overs 1–6)
SELECT
    t.Team_Name,
    ROUND(AVG(pp_runs),2) AS Avg_Powerplay_Runs
FROM
(
    SELECT
        Match_Id,
        Team_Batting,
        SUM(Runs_Scored) AS pp_runs
    FROM ball_by_ball
    WHERE Over_Id BETWEEN 1 AND 6
    GROUP BY Match_Id, Team_Batting
) x
JOIN team t
    ON x.Team_Batting=t.Team_Id
GROUP BY t.Team_Name
ORDER BY Avg_Powerplay_Runs DESC;

-- Batting vs Bowling Efficiency Index
SELECT
    t.Team_Name,
    ROUND(SUM(b.Runs_Scored)/COUNT(DISTINCT b.Match_Id),2) AS Runs_Per_Match,
    ROUND(COUNT(w.Player_Out)/COUNT(DISTINCT b.Match_Id),2) AS Wickets_Per_Match
FROM team t
JOIN ball_by_ball b
    ON t.Team_Id=b.Team_Batting
LEFT JOIN wicket_taken w
    ON b.Match_Id=w.Match_Id
   AND b.Over_Id=w.Over_Id
   AND b.Ball_Id=w.Ball_Id
   AND b.Innings_No=w.Innings_No
GROUP BY t.Team_Name;


-- Q13 Using SQL, write a query to find out the average wickets taken by each bowler in each venue. 
-- Also, rank the gender according to the average value.
 WITH Bowler_Avg_Wickets AS
(
    SELECT
        p.Player_Id,
        p.Player_Name,
        v.Venue_Name,
        ROUND(
            COUNT(wt.Player_Out) * 1.0 /
            COUNT(DISTINCT m.Match_Id),
            2
        ) AS Avg_Wickets
    FROM ball_by_ball bb
    JOIN wicket_taken wt
        ON bb.Match_Id = wt.Match_Id
       AND bb.Innings_No = wt.Innings_No
       AND bb.Over_Id = wt.Over_Id
       AND bb.Ball_Id = wt.Ball_Id
    JOIN player p
        ON bb.Bowler = p.Player_Id
    JOIN matches m
        ON bb.Match_Id = m.Match_Id
    JOIN venue v
        ON m.Venue_Id = v.Venue_Id
    GROUP BY
        p.Player_Id,
        p.Player_Name,
        v.Venue_Name
)
SELECT
    Player_Id,
    Player_Name,
    Venue_Name,
    Avg_Wickets,
    ROW_NUMBER() OVER (
        PARTITION BY Venue_Name
        ORDER BY Avg_Wickets DESC
    ) AS Wicket_Rank
FROM Bowler_Avg_Wickets
ORDER BY Venue_Name, Wicket_Rank;

-- Q14 Which of the given players have consistently performed well in past seasons? 
-- (will you use any visualization to solve the problem)

 SELECT
    p.Player_Name,
    s.Season_Year,
    SUM(b.Runs_Scored) AS Season_Runs
FROM ball_by_ball b
JOIN player p
    ON b.Striker = p.Player_Id
JOIN matches m
    ON b.Match_Id = m.Match_Id
JOIN season s
    ON m.Season_Id = s.Season_Id
WHERE p.Player_Name IN (
    'AB de Villiers',
    'V Kohli',
    'DA Warner',
    'SK Raina',
    'RG Sharma'
)
GROUP BY
    p.Player_Name,
    s.Season_Year
ORDER BY
    p.Player_Name,
    s.Season_Year;




-- Q15 Are there players whose performance is more suited to specific venues or conditions? 
-- (how would you present this using charts?) 

WITH Player_Venue_Runs AS (
    SELECT
        p.Player_Name,
        v.Venue_Name,
        SUM(b.Runs_Scored) AS Total_Runs
    FROM ball_by_ball b
    JOIN player p
        ON b.Striker = p.Player_Id
    JOIN matches m
        ON b.Match_Id = m.Match_Id
    JOIN venue v
        ON m.Venue_Id = v.Venue_Id
    WHERE p.Player_Name IN (
        'V Kohli',
        'DA Warner',
        'AB de Villiers',
        'RG Sharma',
        'SK Raina'
    )
    GROUP BY p.Player_Name, v.Venue_Name
)
SELECT *
FROM (
    SELECT *,
           ROW_NUMBER() OVER(
               PARTITION BY Player_Name
               ORDER BY Total_Runs DESC
           ) AS rn
    FROM Player_Venue_Runs
) x
WHERE rn <= 3
ORDER BY Player_Name, Total_Runs DESC;




                          -- SUBJECTIVE QUESTIONS --

-- Q1 How does the toss decision affect the result of the match?
 --   (which visualizations could be used to present your answer better) And is the impact limited to only specific venues?

-- Overall Toss Impact
SELECT
    COUNT(*) AS Total_Matches,
    SUM(CASE WHEN Toss_Winner = Match_Winner THEN 1 ELSE 0 END) AS Toss_And_Match_Won,
    ROUND(
        SUM(CASE WHEN Toss_Winner = Match_Winner THEN 1 ELSE 0 END) * 100.0
        / COUNT(*), 2
    ) AS Toss_Impact_Percentage
FROM matches;

-- Bat First vs Field First
SELECT
    CASE
        WHEN Toss_Decide = 1 THEN 'Bat First'
        ELSE 'Field First'
    END AS Toss_Decision,
    COUNT(*) AS Matches,
    SUM(CASE WHEN Toss_Winner = Match_Winner THEN 1 ELSE 0 END) AS Wins,
    ROUND(
        SUM(CASE WHEN Toss_Winner = Match_Winner THEN 1 ELSE 0 END) * 100.0
        / COUNT(*), 2
    ) AS Win_Percentage
FROM matches
GROUP BY Toss_Decide;

-- Venue-wise Toss Impact
SELECT
    v.Venue_Name,
    COUNT(*) AS Matches,
    SUM(CASE WHEN m.Toss_Winner = m.Match_Winner THEN 1 ELSE 0 END) AS Toss_And_Match_Won,
    ROUND(
        SUM(CASE WHEN m.Toss_Winner = m.Match_Winner THEN 1 ELSE 0 END) * 100.0
        / COUNT(*), 2
    ) AS Toss_Impact_Percentage
FROM matches m
JOIN venue v
    ON m.Venue_Id = v.Venue_Id
GROUP BY v.Venue_Name
HAVING COUNT(*) >= 5
ORDER BY Toss_Impact_Percentage DESC;





-- Q2 Suggest some of the players who would be best fit for the team
SELECT p.Player_Name, SUM(bb.Runs_Scored) AS Runs, COUNT(*) AS Balls,
  ROUND(SUM(bb.Runs_Scored)*100.0/COUNT(*),2) AS Strike_Rate
FROM Ball_by_Ball bb
JOIN Player p ON bb.Striker = p.Player_Id
WHERE bb.Team_Batting = 2
GROUP BY p.Player_Name
HAVING Balls >= 100
ORDER BY Runs DESC;
SELECT p.Player_Name, COUNT(*) AS Balls, SUM(bb.Runs_Scored) AS Runs_Conceded,
  ROUND(SUM(bb.Runs_Scored)*6.0/COUNT(*),2) AS Economy
FROM Ball_by_Ball bb
JOIN Player p ON bb.Bowler = p.Player_Id
WHERE bb.Team_Bowling = 2
GROUP BY p.Player_Name
HAVING Balls >= 120
ORDER BY Economy ASC;



-- Q3 What are some of the parameters that should be focused on while selecting the players?
SELECT
    p.Player_Name,
    SUM(b.Runs_Scored) AS Total_Runs,
    ROUND((SUM(b.Runs_Scored) * 100.0) / COUNT(*), 2) AS Strike_Rate,
    COALESCE(wk.Total_Wickets, 0) AS Total_Wickets
FROM ball_by_ball b
JOIN player p
    ON b.Striker = p.Player_Id
LEFT JOIN (
    SELECT
        b.Bowler,
        COUNT(w.Player_Out) AS Total_Wickets
    FROM ball_by_ball b
    JOIN wicket_taken w
        ON b.Match_Id = w.Match_Id
        AND b.Innings_No = w.Innings_No
        AND b.Over_Id = w.Over_Id
        AND b.Ball_Id = w.Ball_Id
    GROUP BY b.Bowler
) wk
    ON p.Player_Id = wk.Bowler
GROUP BY p.Player_Id, p.Player_Name, wk.Total_Wickets
HAVING SUM(b.Runs_Scored) > 500
ORDER BY Total_Runs DESC, Strike_Rate DESC;



-- Q4  Which players offer versatility in their skills and can contribute effectively with both bat and ball?
-- (can you visualize the data for the same)
WITH Batting AS (
    SELECT
        Striker AS Player_Id,
        SUM(Runs_Scored) AS Total_Runs
    FROM ball_by_ball
    GROUP BY Striker
),
Bowling AS (
    SELECT
        b.Bowler AS Player_Id,
        COUNT(w.Player_Out) AS Total_Wickets
    FROM ball_by_ball b
    JOIN wicket_taken w
      ON b.Match_Id = w.Match_Id
     AND b.Innings_No = w.Innings_No
     AND b.Over_Id = w.Over_Id
     AND b.Ball_Id = w.Ball_Id
    GROUP BY b.Bowler
)
SELECT
    p.Player_Name,
    COALESCE(bt.Total_Runs,0) AS Total_Runs,
    COALESCE(bw.Total_Wickets,0) AS Total_Wickets
FROM player p
JOIN Batting bt
    ON p.Player_Id = bt.Player_Id
JOIN Bowling bw
    ON p.Player_Id = bw.Player_Id
WHERE bt.Total_Runs > 1000
  AND bw.Total_Wickets > 10
ORDER BY Total_Wickets DESC, Total_Runs DESC;




-- Q5 Are there players whose presence positively influences the morale and performance of the team?
--  (justify your answer using visualization)

WITH MOTM AS (
    SELECT
        Man_of_the_Match AS Player_Id,
        COUNT(*) AS Man_Of_The_Match_Awards
    FROM matches
    GROUP BY Man_of_the_Match
),
RUNS AS (
    SELECT
        Striker AS Player_Id,
        SUM(Runs_Scored) AS Total_Runs
    FROM ball_by_ball
    GROUP BY Striker
)
SELECT
    p.Player_Name,
    m.Man_Of_The_Match_Awards,
    COALESCE(r.Total_Runs,0) AS Total_Runs
FROM MOTM m
JOIN player p
    ON m.Player_Id = p.Player_Id
LEFT JOIN RUNS r
    ON p.Player_Id = r.Player_Id
ORDER BY m.Man_Of_The_Match_Awards DESC, Total_Runs DESC
LIMIT 10;




-- Q6 What would you suggest to RCB before going to the mega auction? 

WITH Batting AS (
    SELECT
        Striker AS Player_Id,
        SUM(Runs_Scored) AS Total_Runs
    FROM ball_by_ball
    GROUP BY Striker
),
Bowling AS (
    SELECT
        b.Bowler AS Player_Id,
        COUNT(w.Player_Out) AS Total_Wickets
    FROM ball_by_ball b
    JOIN wicket_taken w
      ON b.Match_Id = w.Match_Id
     AND b.Innings_No = w.Innings_No
     AND b.Over_Id = w.Over_Id
     AND b.Ball_Id = w.Ball_Id
    GROUP BY b.Bowler
)
SELECT
    p.Player_Name,
    COALESCE(bt.Total_Runs,0) AS Total_Runs,
    COALESCE(bw.Total_Wickets,0) AS Total_Wickets,
    (COALESCE(bt.Total_Runs,0) + (COALESCE(bw.Total_Wickets,0) * 20)) AS Player_Score
FROM player p
LEFT JOIN Batting bt
    ON p.Player_Id = bt.Player_Id
LEFT JOIN Bowling bw
    ON p.Player_Id = bw.Player_Id
ORDER BY Player_Score DESC
LIMIT 15;




-- Q7 What do you think could be the factors contributing to the high-scoring matches and the impact on viewership and team strategies
SELECT 
    v.Venue_Name,
    ROUND(AVG(bbb.Runs_Scored), 2) AS Avg_Runs_Per_Ball,
    ROUND(SUM(bbb.Runs_Scored) * 1.0 / COUNT(DISTINCT m.Match_Id), 2) AS Avg_Total_Per_Match
FROM ball_by_ball bbb
JOIN matches m 
    ON bbb.Match_Id = m.Match_Id
JOIN venue v 
    ON m.Venue_Id = v.Venue_Id
GROUP BY v.Venue_Name
ORDER BY Avg_Total_Per_Match DESC;




-- Q8 Analyze the impact of home-ground advantage on team performance and identify strategies to maximize this advantage for RCB.
  SELECT
    CASE
        WHEN v.Venue_Name = 'M Chinnaswamy Stadium'
        THEN 'Home Ground'
        ELSE 'Away Ground'
    END AS Venue_Type,
    COUNT(*) AS Matches_Played,
    SUM(
        CASE
            WHEN m.Match_Winner = (
                SELECT Team_Id
                FROM team
                WHERE Team_Name = 'Royal Challengers Bangalore'
            )
            THEN 1
            ELSE 0
        END
    ) AS Matches_Won,
    ROUND(
        SUM(
            CASE
                WHEN m.Match_Winner = (
                    SELECT Team_Id
                    FROM team
                    WHERE Team_Name = 'Royal Challengers Bangalore'
                )
                THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS Win_Percentage
FROM matches m
JOIN venue v
    ON m.Venue_Id = v.Venue_Id
WHERE (
    m.Team_1 = (
        SELECT Team_Id
        FROM team
        WHERE Team_Name = 'Royal Challengers Bangalore'
    )
    OR
    m.Team_2 = (
        SELECT Team_Id
        FROM team
        WHERE Team_Name = 'Royal Challengers Bangalore'
    )
)
GROUP BY Venue_Type;






-- Q11 In the "Match" table, some entries in the "Opponent_Team" column are incorrectly spelled as "Delhi_Capitals" instead of "Delhi_Daredevils".
--  Write an SQL query to replace all occurrences of "Delhi_Capitals" with "Delhi_Daredevils".
desc matches;
SELECT Team_Id, Team_Name
FROM team
WHERE Team_Name LIKE '%Delhi%';

