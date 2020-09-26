.PHONY: app
app: up
	docker run --rm -it -v `pwd`:/app -w /app --network=crispy_disco_default erlang:23.1 rebar3 shell

.PHONY: up
up:
	docker-compose up -d connect

.PHONY: sql
sql:
	docker-compose run db mysql -h db -u root crispy_disco

.PHONY: load_dump
load_dump:
	docker-compose run db mysql -h db -u root -e "source /var/data/dump.sql"

################
### Debezium ###
################
.PHONY: watch
watch:
	docker-compose run --rm -e "KAFKA_BROKER=kafka:9092" kafka watch-topic -a -k dbserver1.crispy_disco.pokemons

.PHONY: register_connector
register_connector: connector.json
	curl -i \
		-H "Accept: application/json" \
		-H "Content-Type: application/json" \
		-d @connector.json \
		http://localhost:8083/connectors/

.PHONY: check_connector
check_connector:
	curl -s -H "Accept: application/json" http://localhost:8083/connectors/ | jq .

.PHONY: review_connector
review_connector:
	curl -s -H "Accept: application/json" http://localhost:8083/connectors/pokemons-connector | jq .

# See https://github.com/shyiko/mysql-binlog-connector-java/issues/240#issuecomment-494434539
.PHONY: fix_password_error
fix_password_error:
	docker-compose run db mysql -u root -h db -e "ALTER USER root IDENTIFIED WITH mysql_native_password BY ''"
