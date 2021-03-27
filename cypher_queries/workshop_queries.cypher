//////////////////////////////////
// GENERAL QUERIES
//////////////////////////////////

// Delete all nodes and edges in graph
MATCH (n) DETACH DELETE n

// Remove a property from all nodes
MATCH (n:Node) 
REMOVE n.property_name 
RETURN n LIMIT 1

// Get history of previous commands (default limit: 30)
CALL db.labels()

//////////////////////////////////
// WORKSHOP-SPECIFIC QUERIES
//////////////////////////////////

// Where is Michelle Obama?
MATCH (n:Node)
WHERE n.name CONTAINS 'michelle'
RETURN n.name

// Update node labels based on node_labels list
MATCH (n:Node) 
CALL apoc.create.addLabels(n, n.node_labels) 
YIELD node 
RETURN node

// How many Obama's are in the graph?

MATCH (n:Node)
WHERE n.name CONTAINS 'obama'
RETURN DISTINCT n.name

// Check for duplicates
MATCH (n:Node)
WITH n.name AS name, n.node_labels AS labels, COLLECT(n) AS nodes
WHERE SIZE(nodes) > 1
RETURN [n in nodes | n.name] AS names, [n in nodes | n.node_labels] as labels, SIZE(nodes)
ORDER BY SIZE(nodes) DESC

// Drop duplicates
MATCH (n:Node) 
WITH n.name AS name, COLLECT(n) AS nodes 
WHERE SIZE(nodes)>1 
FOREACH (el in nodes | DETACH DELETE el)

// Get the cosine similarity between two nodes

MATCH (n1:Node {name: 'barack obama'}) 
MATCH (n2:Node {name: 'mitch mcconnell'}) 
RETURN gds.alpha.similarity.cosine(n1.word_vec, n2.word_vec) AS similarity

// Compute Levenshtein distance on related nodes
// (how many characters have to change between n1 and n2)
MATCH (n1:Node {name: 'barack obama'}) 
MATCH (n2:Node) WHERE n2.name CONTAINS 'obama' 
RETURN n2.name, apoc.text.distance(n1.name, n2.name) AS distance

// Can we figure out the nationality of 'oh bah mə'
MATCH (n:Node {name: 'oh bah mə'})-[*1..5]->(p) 
WHERE p:Country OR p:AdministrativeArea OR p:Continent OR p:Place
RETURN n, p

MATCH (n:Node {name: 'oh bah mə'})-[:be|:bear]->(p) 
WHERE p:Country OR p:AdministrativeArea OR p:Continent OR p:Place 
RETURN n, p

// What about all Obamas?
MATCH (n:Node)-[*1..5]->(p) 
WHERE n.name CONTAINS 'obama' 
AND p:Country OR p:AdministrativeArea OR p:Continent OR p:Place 
RETURN n, p

// Create person, place, thing labels
MATCH (n)
WHERE ANY (x in n.node_labels WHERE x IN ['Organization', 'EducationalOrganization', 'Corporation', 'SportsTeam', 'SportsOrganization', 'GovernmentOrganization'])
CALL apoc.create.addLabels(n, ['Person'])
YIELD node
RETURN node

MATCH (n)
WHERE ANY (x in n.node_labels WHERE x IN ['AdministrativeArea', 'Country', 'Museum', 'TouristAttraction', 'CivicStructure', 'City', 'CollegeOrUniversity',
                'MovieTheater', 'Continent', 'MusicVenue', 'LandmarksOrHistoricalBuildings', 'Cemetery', 'BodyOfWater',
                'PlaceOfWorship', 'Restaurant', 'LakeBodyOfWater'])
CALL apoc.create.addLabels(n, ['Place'])
YIELD node
RETURN node

MATCH (n)
WHERE ANY (x in n.node_labels WHERE x IN ['Periodical', 'Book', 'Movie', 'Event', 'MusicComposition', 'SoftwareApplication', 'ProductMode', 'DefenceEstablishment',
                'MusicRecording', 'LocalBusiness', 'CreativeWork', 'Article', 'TVEpisode', 'ItemList', 'TVSeries', 'Airline',
                'Product', 'VisualArtwork', 'VideoGame', 'Brand'])
CALL apoc.create.addLabels(n, ['Thing'])
YIELD node
RETURN node

MATCH (n)
WHERE SIZE(labels(n)) = 1
CALL apoc.create.addLabels(n, ['Unknown'])
YIELD node
RETURN node

// Create an in-memory graph of all nodes and relationships
CALL gds.graph.create('all_nodes', 'Node', '*') 
YIELD graphName, nodeCount, relationshipCount

// Create an in-memory graph based on PPT-U labels
CALL gds.graph.create(
	'pptu_graph',
    {
    	Person: {label: 'Person'},
        Place: {label: 'Place'},
        Thing: {label: 'Thing'},
        Unknown: {label: 'Unknown'}
    },
    '*'
)
YIELD graphName, nodeCount, relationshipCount

// Run FastRP on full in-memory graph and output results to screen
CALL gds.fastRP.stream('all_nodes', {embeddingDimension: 10})
YIELD nodeId, embedding
RETURN gds.util.asNode(nodeId).name as name, embedding

// Write FastRP embeddings as a vector to each node
CALL gds.fastRP.write('all_nodes', 
    { 
        embeddingDimension: 100, 
        writeProperty: 'fastrp_100'
    } 
)
