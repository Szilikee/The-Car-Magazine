using Microsoft.EntityFrameworkCore;
using TheCarMagazinAPI.Models;

namespace TheCarMagazinAPI.Data
{
    public class ApplicationDbContext : DbContext
    {
        // DbSet-ek
        public DbSet<User> Users { get; set; }

        // Konstruktor, amely az adatbázis kapcsolatot inicializálja
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options) { }

        // Modellek konfigurálása
        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

        }
    }
}
