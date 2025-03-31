using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MySql.Data.MySqlClient;
using System.Security.Claims;

[Route("api/forum")]
[ApiController]
public class ForumController : ControllerBase
{
    private readonly string _connectionString;
    public ForumController(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection");
    }

    [HttpGet("topics")]
    public async Task<IActionResult> GetTopics()
    {
        using var connection = new MySqlConnection(_connectionString);
        var topics = await connection.QueryAsync("SELECT id, topic, description, created_at AS createdAt, username FROM topics");
        return Ok(topics);
    }

    [HttpGet("topics/{topicId}/subtopics")]
    public async Task<IActionResult> GetSubtopics(long topicId)
    {
        using var connection = new MySqlConnection(_connectionString);
        var subtopics = await connection.QueryAsync(
            "SELECT id, title, description, created_at AS createdAt, username FROM subtopics WHERE topic_id = @TopicId",
            new { TopicId = topicId });
        return Ok(subtopics);
    }

    [HttpPost("topics/{topicId}/subtopics")]
    [Authorize]
    public async Task<IActionResult> CreateSubtopic(long topicId, [FromBody] SubtopicDto subtopicDto)
    {
        using var connection = new MySqlConnection(_connectionString);
        var userId = long.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);
        var subtopicId = await connection.ExecuteScalarAsync<long>(
            "INSERT INTO subtopics (topic_id, title, description, user_id, created_at) VALUES (@TopicId, @Title, @Description, @UserId, NOW()); SELECT LAST_INSERT_ID();",
            new { TopicId = topicId, subtopicDto.Title, subtopicDto.Description, UserId = userId });
        return CreatedAtAction(nameof(GetSubtopics), new { topicId }, new { id = subtopicId });
    }

    [HttpGet("subtopics/{subtopicId}/posts")]
    public async Task<IActionResult> GetPosts(long subtopicId)
    {
        using var connection = new MySqlConnection(_connectionString);
        var posts = await connection.QueryAsync(
            "SELECT id, content, created_at AS createdAt, username FROM posts WHERE subtopic_id = @SubtopicId",
            new { SubtopicId = subtopicId });
        return Ok(posts);
    }

    [HttpPost("subtopics/{subtopicId}/posts")]
    [Authorize]
    public async Task<IActionResult> CreatePost(long subtopicId, [FromBody] PostDto postDto)
    {
        using var connection = new MySqlConnection(_connectionString);
        var userId = long.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);
        var postId = await connection.ExecuteScalarAsync<long>(
            "INSERT INTO posts (subtopic_id, content, user_id, created_at) VALUES (@SubtopicId, @Content, @UserId, NOW()); SELECT LAST_INSERT_ID();",
            new { SubtopicId = subtopicId, postDto.Content, UserId = userId });
        return CreatedAtAction(nameof(GetPosts), new { subtopicId }, new { id = postId });
    }
}

public class SubtopicDto
{
    public string Title { get; set; }
    public string Description { get; set; }
}

public class PostDto
{
    public string Content { get; set; }
}