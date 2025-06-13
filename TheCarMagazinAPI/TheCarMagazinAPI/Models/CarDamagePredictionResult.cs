using System.Collections.Generic;
using TheCarMagazinAPI.Models;

namespace TheCarMagazinAPI.Models
{
    public class CarDamagePredictionResult
    {
        public List<PredictionResult> Predictions { get; set; }
        public string AnnotatedImage { get; set; } // Base64-encoded image
    }
}