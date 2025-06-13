using System.ComponentModel.DataAnnotations.Schema;
using Dapper; // Ensure this is included

namespace TheCarMagazinAPI.Models
{
    public class ForumTopic
    {
        public int Id { get; set; }
        public string Topic { get; set; }
        public string Description { get; set; }
        [Column("created_at")] // Explicitly map to the database column
        public DateTime CreatedAt { get; set; }
    }

    public class Topic { public long Id { get; set; } public string TopicName { get; set; } /* ... */ }
    public class Subtopic
    {
        public long Id { get; set; }
        public long TopicId { get; set; }
        public string Title { get; set; } = string.Empty;
        public string? Description { get; set; }
        public DateTime CreatedAt { get; set; }
        public long? UserId { get; set; }
        public string? Username { get; set; }
    }
    public class Post
    {
        public long Id { get; set; }
        public long UserId { get; set; }
        public long SubtopicId { get; set; }
        public string Content { get; set; }
        public long? ParentPostId { get; set; } // Nullable for top-level posts
        public DateTime CreatedAt { get; set; }
        public string Username { get; set; } // Optional: Include for display purposes
    }
}
