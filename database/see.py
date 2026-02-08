from neo4j import GraphDatabase

URI = "bolt://localhost:7687"
AUTH = ("neo4j", "your_password")

def seed_database():
    driver = GraphDatabase.driver(URI, auth=AUTH)
    with driver.session() as session:
        # This deletes old data and starts fresh
        session.run("MATCH (n) DETACH DELETE n") 
        
        # The Seed Script
        session.run("""
            CREATE (n1:Node {name: 'Stress', id: 1})
            CREATE (n2:Node {name: 'Emotional Struggle', id: 2})
            CREATE (n3:Node {name: 'Procrastination', id: 3})
            // ... (add the rest of the nodes here)
            CREATE (n1)-[:LEADS_TO]->(n2)
        """)
        print("Cycle successfully seeded!")
    driver.close()

if __name__ == "__main__":
    seed_database()