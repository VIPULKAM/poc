echo "Setting up the environment , please wait...."
sudo apt -y update < "/dev/null"
sudo apt -y install gosu < "/dev/null"
echo "gosu installed...."
sudo apt -y install postgresql-12 postgresql-client-12 < "/dev/null"
echo "PostgreSQL installed...."
echo "
listen_addresses = '*'
port = 6432
log_connections = on
log_disconnections = on
log_statement = 'all'
log_replication_commands = on" >> /etc/postgresql/12/main/postgresql.conf
echo "Configuration file modified..."
sudo pg_ctlcluster 12 main restart
sleep 1
export PATH=$PATH:/usr/lib/postgresql/12/bin/
echo "Switching to postgres user..."
echo "Creating schema..."
sudo -u postgres -H -- psql -d postgres << EOF
\pset pager off
/* Produce a random string at a given length from a list of possible characters. */
CREATE OR REPLACE FUNCTION generate_random_string(
  length INTEGER,
  characters TEXT default '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
) RETURNS TEXT AS
\$\$
DECLARE
  result TEXT := '';
BEGIN
  IF length < 1 then
      RAISE EXCEPTION 'Invalid length';
  END IF;
  FOR __ IN 1..length LOOP
    result := result || substr(characters, floor(random() * length(characters))::int + 1, 1);
  end loop;
  RETURN result;
END;
\$\$ LANGUAGE plpgsql;
/* Create Short URLs table */
DROP TABLE IF EXISTS shorturl;
CREATE TABLE shorturl (
    id int generated by default as identity primary key,
    key varchar(6) unique not null,
    url text not null,
    hits int not null,
    created_at timestamptz not null,
    constraint hits_gte_zero_check CHECK (hits >= 0)
);
/* Populate Short URLs table. */
BEGIN;
-- Use `setseed` to produce consistent results (only affect `random` calls in current transaction)
SELECT setseed(1);
INSERT INTO shorturl (
    key,
    url,
    created_at,
    hits
)
SELECT
    -- A random 6 digit key
    generate_random_string(6) AS key,
    -- Generate random domain and path, and use some domain that repeats itself.
    CASE
        WHEN random() < 0.1 THEN 'https://hakibenita.com'
        ELSE 'https://' || generate_random_string(2 + ceil(random() * 8)::int) || '.com'
    END || '/' || generate_random_string(5) AS url,
    -- Generate incremeting creations dates with some jitter, starting at 2021-01-01.
    '2021-01-01 UTC'::timestamptz + (interval '10 minutes') * n + interval '11 minutes' * random() AS created_at,
    -- Generate random hit count, with ~1% of the shorturls having no hits.
    CASE
        WHEN random() < 0.01 THEN 0
        ELSE ceil(random() * 10000)
    END AS hits
FROM
    -- Generate 10_000 rows, adjust if neccessary.
    generate_series(1, 10000) AS n;
COMMIT;
VACUUM ANALYZE shorturl;
EOF
sudo -u postgres -H -- psql -d postgres --pset=pager=off
